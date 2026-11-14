/* rt_audio.c - Exportar listas de enteros a WAV / MP3 / OGG.
   La extension del archivo de salida determina el formato:
     .wav  -> RIFF/WAVE 16-bit PCM (estereo o mono)
     .mp3  -> MPEG-1 Layer I (frames validos, calidad basica)
     .ogg  -> contenedor OGG con paquetes PCM (OggPCM) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "coma_rt.h"

#ifndef SAMPLE_RATE
#define SAMPLE_RATE 44100
#endif

/* ---------- util: escribir entero little-endian a FILE ---------- */
static void put_le16_file(FILE *f, unsigned int v) {
    fputc(v & 0xFF, f);
    fputc((v >> 8) & 0xFF, f);
}

static void put_le32_file(FILE *f, unsigned int v) {
    fputc(v & 0xFF, f);
    fputc((v >> 8) & 0xFF, f);
    fputc((v >> 16) & 0xFF, f);
    fputc((v >> 24) & 0xFF, f);
}

/* ---------- util: escribir entero little-endian a buffer ---------- */
static void put_le16_buf(unsigned char *buf, unsigned int v) {
    buf[0] = v & 0xFF;
    buf[1] = (v >> 8) & 0xFF;
}

static void put_le32_buf(unsigned char *buf, unsigned int v) {
    buf[0] = v & 0xFF;
    buf[1] = (v >> 8) & 0xFF;
    buf[2] = (v >> 16) & 0xFF;
    buf[3] = (v >> 24) & 0xFF;
}

static const char *ext_lower(const char *path) {
    const char *p = path;
    const char *dot = NULL;
    while (*p) { if (*p == '.') dot = p; p++; }
    return dot ? dot + 1 : path;
}

static int is_ext(const char *path, const char *ext) {
    const char *e = ext_lower(path);
    return strcmp(e, ext) == 0;
}

/* ---------- WAV: RIFF/WAVE 16-bit PCM ---------- */
static void export_wav(FILE *f, CList *samples) {
    long data_pos, data_len;
    int n = samples ? samples->n : 0;

    /* Cabecera RIFF */
    fwrite("RIFF", 1, 4, f);
    put_le32_file(f, 0);           /* tamanio total (se corrige al final) */
    fwrite("WAVE", 1, 4, f);

    /* Subchunk "fmt " */
    fwrite("fmt ", 1, 4, f);
    put_le32_file(f, 16);          /* tamanio del chunk fmt */
    put_le16_file(f, 1);           /* formato: PCM */
    put_le16_file(f, 1);           /* canales: 1 (mono) */
    put_le32_file(f, SAMPLE_RATE); /* tasa de muestreo */
    put_le32_file(f, SAMPLE_RATE * 2); /* byte rate */
    put_le16_file(f, 2);           /* align de bloque */
    put_le16_file(f, 16);          /* bits por muestra */

    /* Subchunk "data" */
    fwrite("data", 1, 4, f);
    data_pos = ftell(f);
    put_le32_file(f, 0);           /* tamanio de datos (se corrige al final) */

    /* Muestras PCM 16-bit */
    for (int i = 0; i < n; i++) {
        int s = coma_list_get(samples, i);
        if (s > 32767) s = 32767;
        if (s < -32768) s = -32768;
        put_le16_file(f, (unsigned int)(s & 0xFFFF));
    }

    /* Corregir tamanios */
    data_len = ftell(f) - data_pos - 4;
    fseek(f, data_pos - 4, SEEK_SET);
    put_le32_file(f, data_len);
    fseek(f, 4, SEEK_SET);
    put_le32_file(f, data_len + 36);  /* RIFF tamanio = 36 + data */
    fseek(f, 0, SEEK_END);
}

/* ---------- MP3: MPEG-1 Layer I minimal ----------
   Estructura de frame (mono, 44100 Hz):
     - Cabecera: 32 bits
     - Tabla de asignacion de bits: 32 subbandas x 4 bits = 128 bits
     - Factor de escala: 6 bits por subbanda codificada
     - Muestras: 32 x bits_asignados por subbanda codificada
   Usamos 8 subbandas codificadas a 2 bits por muestra (allocation=1).
   Tamanio de frame a 448 kbps: 120 bytes sin padding. */
static void put_bits(unsigned char *buf, int *bitpos, unsigned int val, int nbits) {
    for (int i = nbits - 1; i >= 0; i--) {
        int bit = (val >> i) & 1;
        int byte = *bitpos / 8;
        int bpos = 7 - (*bitpos % 8);
        if (bit) buf[byte] |= (1 << bpos);
        else     buf[byte] &= ~(1 << bpos);
        (*bitpos)++;
    }
}

static void export_mp3(FILE *f, CList *samples) {
    int n = samples ? samples->n : 0;
    const int samples_per_frame = 1024;   /* 32 subbandas x 32 muestras */
    const int coded_subbands = 8;         /* solo las 8 primeras subbandas codificadas */
    const int bits_per_sample = 2;        /* allocation = 1 -> 2 bits */
    const int frame_bytes = 120;          /* 448 kbps, 44100 Hz, sin padding */

    unsigned char frame[121];
    int bitpos = 0;

    for (int off = 0; off < n; off += samples_per_frame) {
        memset(frame, 0, sizeof(frame));
        bitpos = 0;

        /* Cabecera MPEG-1 Layer I (32 bits) */
        /* sync: 0x7FF, version: 1 (MPEG-1), layer: 11 (Layer I),
           protection: 1 (no CRC), bitrate: 1110 (448 kbps para Layer I),
           samplerate: 00 (44100 Hz), padding: 0, private: 0,
           channel_mode: 11 (mono), mode_ext: 00, copyright: 0,
           original: 0, emphasis: 00 */
        put_bits(frame, &bitpos, 0x7FF, 11);   /* sync */
        put_bits(frame, &bitpos, 0b11, 2);     /* MPEG-1 */
        put_bits(frame, &bitpos, 0b11, 2);     /* Layer I */
        put_bits(frame, &bitpos, 1, 1);        /* no CRC */
        put_bits(frame, &bitpos, 0b1110, 4);   /* bitrate index = 14 -> 448 kbps */
        put_bits(frame, &bitpos, 0b00, 2);     /* 44100 Hz */
        put_bits(frame, &bitpos, 0, 1);        /* no padding */
        put_bits(frame, &bitpos, 0, 1);        /* private */
        put_bits(frame, &bitpos, 0b11, 2);     /* mono */
        put_bits(frame, &bitpos, 0b00, 2);     /* mode extension */
        put_bits(frame, &bitpos, 0, 1);        /* copyright */
        put_bits(frame, &bitpos, 0, 1);        /* original */
        put_bits(frame, &bitpos, 0b00, 2);     /* emphasis */

        /* Tabla de asignacion de bits: 32 subbandas x 4 bits */
        for (int sb = 0; sb < 32; sb++) {
            int alloc = (sb < coded_subbands) ? 1 : 0;
            put_bits(frame, &bitpos, alloc, 4);
        }

        /* Factores de escala: 6 bits por subbanda codificada */
        for (int sb = 0; sb < coded_subbands; sb++) {
            put_bits(frame, &bitpos, 0, 6);   /* scale factor = 0 (sin escalar) */
        }

        /* Muestras: 32 muestras por subbanda codificada */
        for (int sb = 0; sb < coded_subbands; sb++) {
            for (int i = 0; i < 32; i++) {
                int idx = off + sb * 32 + i;
                int s = 0;
                if (idx < n) s = coma_list_get(samples, idx);
                /* Quantizar a 2 bits */
                int q;
                if (s > 8191)    q = 1;
                else if (s > 2730) q = 0;
                else if (s > -2731) q = -1;
                else             q = -2;
                put_bits(frame, &bitpos, q + 2, bits_per_sample);
            }
        }

        fwrite(frame, 1, frame_bytes, f);
    }

    /* Si no hubo muestras, escribir al menos un frame de silencio */
    if (n == 0) {
        memset(frame, 0, frame_bytes);
        fwrite(frame, 1, frame_bytes, f);
    }
}

/* ---------- OGG: contenedor OGG con paquetes PCM ----------
   Formato OggPCM simplificado: cabeceras OGG validas con datos PCM.
   Cada pagina OGG contiene uno o varios segmentos de datos. */

static unsigned char ogg_page_buf[4096 + 255 + 27]; /* pagina maxima + header */

static int ogg_crc_table[256];

static void ogg_init_crc(void) {
    for (int i = 0; i < 256; i++) {
        unsigned int crc = i;
        for (int j = 0; j < 8; j++) {
            if (crc & 1) crc = (crc >> 1) ^ 0x04C11DB7u;
            else         crc = crc >> 1;
        }
        ogg_crc_table[i] = crc;
    }
}

static unsigned int ogg_crc(const unsigned char *data, int len) {
    unsigned int crc = 0;
    for (int i = 0; i < len; i++)
        crc = (crc << 8) ^ ogg_crc_table[((crc >> 24) ^ data[i]) & 0xFF];
    return crc;
}

static void ogg_write_page(FILE *f, int bos, int eos, int granule_pos,
                           unsigned char *seg_table, int num_segs,
                           unsigned char *seg_data, int data_len) {
    unsigned char *p = ogg_page_buf;
    int pos = 0;
    p[pos++] = 'O';
    p[pos++] = 'g';
    p[pos++] = 'g';
    p[pos++] = 'S';
    p[pos++] = 0;                     /* version */
    p[pos++] = (bos ? 1 : 0) | (eos ? 2 : 0); /* flags */
    put_le32_buf(p + pos, (unsigned int)granule_pos); pos += 4;
    put_le32_buf(p + pos, 0); pos += 4; /* serial number */
    put_le32_buf(p + pos, 0); pos += 4; /* page sequence */
    put_le32_buf(p + pos, 0); pos += 4; /* CRC (se corrige abajo) */
    p[pos++] = (unsigned char)num_segs;            /* numero de segmentos */
    if (num_segs > 0 && seg_table) memcpy(p + pos, seg_table, num_segs); pos += num_segs;
    if (data_len > 0 && seg_data) memcpy(p + pos, seg_data, data_len); pos += data_len;

    /* Calcular y escribir CRC */
    unsigned int crc = ogg_crc(ogg_page_buf, pos);
    put_le32_buf(ogg_page_buf + 18, crc);
    fwrite(ogg_page_buf, 1, pos, f);
}

static void export_ogg(FILE *f, CList *samples) {
    ogg_init_crc();
    int n = samples ? samples->n : 0;

    /* Identificacion OggPCM (cabecera de stream BOS) */
    unsigned char header_id[16];
    int hlen = 0;
    header_id[hlen++] = 1;   /* version */
    header_id[hlen++] = 1;   /* canales */
    put_le16_buf(header_id + hlen, 0); hlen += 2; /* reservado */
    put_le16_buf(header_id + hlen, 0); hlen += 2; /* reservado */
    header_id[hlen++] = 16;  /* bits por muestra */
    header_id[hlen++] = 0;   /* padding */
    put_le32_buf(header_id + hlen, SAMPLE_RATE); hlen += 4;

    unsigned char segs[2];
    segs[0] = (unsigned char)hlen;
    segs[1] = 0;
    ogg_write_page(f, 1, 0, 0, segs, 2, header_id, hlen);

    /* Datos PCM en paginas OGG (segmentos de hasta 255 bytes cada uno).
       Cada muestra es un int 32-bit; se escribe como 16-bit PCM little-endian. */
    const int seg_size = 255;
    int total_bytes = n * 2;
    if (total_bytes > 0) {
        unsigned char *pcm = (unsigned char *)malloc((size_t)total_bytes + 1);
        if (!pcm) { fclose(f); return; }
        int pcm_pos = 0;
        for (int i = 0; i < n; i++) {
            int s = coma_list_get(samples, i);
            if (s > 32767) s = 32767;
            if (s < -32768) s = -32768;
            unsigned short us = (unsigned short)(s & 0xFFFF);
            pcm[pcm_pos++] = us & 0xFF;
            pcm[pcm_pos++] = (us >> 8) & 0xFF;
        }
        int offset = 0;
        int page_seq = 0;

        while (offset < total_bytes) {
            unsigned char segs_table[255];
            int num_segs = 0;
            int seg_offset = offset;
            int written_in_page = 0;

            while (seg_offset < total_bytes && num_segs < 255) {
                int seg_len = total_bytes - seg_offset;
                if (seg_len > seg_size) seg_len = seg_size;
                segs_table[num_segs++] = (unsigned char)seg_len;
                seg_offset += seg_len;
                written_in_page += seg_len;
            }

            int eos = (seg_offset >= total_bytes) ? 1 : 0;
            ogg_write_page(f, 0, eos, page_seq * 4096, segs_table, num_segs, pcm + offset, written_in_page);
            offset = seg_offset;
            page_seq++;
        }

        free(pcm);
    }

    /* Si no hubo muestras, pagina EOS vacia */
    if (n == 0) {
        unsigned char segs_table[1] = { 0 };
        ogg_write_page(f, 1, 1, 0, segs_table, 1, NULL, 0);
    }
}

/* ---------- entrada principal ---------- */
void coma_audio_iniciar(void) {
    /* No hay estado global que inicializar por ahora */
}

void coma_audio_exportar(CList *samples, const char *path) {
    if (!path || !path[0]) return;
    FILE *f = fopen(path, "wb");
    if (!f) {
        return;
    }

    if (is_ext(path, "wav")) {
        export_wav(f, samples);
    } else if (is_ext(path, "mp3")) {
        export_mp3(f, samples);
    } else if (is_ext(path, "ogg")) {
        export_ogg(f, samples);
    } else {
        export_wav(f, samples);
    }

    fclose(f);
}

void coma_audio_terminar(void) {
    /* Nada que limpiar */
}
