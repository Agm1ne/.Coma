// .Coma IDE v0.1 — logica pura (sin DOM): verificador inicial E001/E002/E004/E006.
// Se carga desde coma-ide.html con <script src> y se prueba con node.
(function (g) {
  "use strict";

  var KEYWORDS = [
    // ES: canonicas + formales + normales + coloquiales
    "mostrar", "enseñar", "exponer", "exhibir", "presentar", "desplegar",
    "indicar", "muestra", "enseña", "mira", "canta", "suelta", "chivate", "di",
    "pedir", "solicitar", "preguntar", "dime", "dame", "pasa",
    "en_caso_de_que", "si", "en_el_caso_de_que", "siempre_que", "dado_que",
    "si_es_que", "cuando",
    "sino", "si_no", "de_lo_contrario", "en_caso_contrario", "en_otro_caso", "pero",
    "fin", "final", "termina_aqui", "se_acabo", "basta", "listo", "ya",
    "mientras", "dale",
    "funcion", "procedimiento", "rutina",
    "devolver", "retornar", "entregar",
    "y", "e", "con",
    "o", "u",
    "no",
    "igual", "es", "vale", "equivale_a", "es_igual_a",
    "mas", "más", "suma",
    "menos", "resta", "quita",
    "por", "multiplica", "veces",
    "entre", "divide", "dividido_entre", "dividido_por",
    "es_mayor_que", "mayor_que", "mas_grande_que", "supera_a",
    "es_menor_que", "menor_que", "mas_chico_que", "mas_pequeno_que", "no_llega_a",
    "es_distinto_de", "distinto_de", "diferente_de",
    "es_mayor_o_igual", "es_menor_o_igual",
    "verdad", "verdadero", "cierto", "simon",
    "falso", "mentira", "nel",
    "lista", "coleccion", "conjunto", "grupo",
    "vacia", "sin_nada",
    "elemento", "pieza", "parte", "miembro", "casilla", "id",
    "primero", "cabeza",
    "ultimo", "último", "cola",
    "longitud", "largo", "tamano",
    "agregar", "añadir", "anadir", "meter",
    "quitar", "sacar", "eliminar", "borrar", "remover",
    "de", "a",
    "en", "dentro", "dentro_de",
    "registro", "ficha", "caja", "paquete",
    "poner", "mete", "coloca", "asigna", "fija",
    "puntero", "dedo",
    "para", "alto", "detente", "frena",
    "sigue", "continua", "continúa",
    "por_cada", "cada",
    "como",
    "segun", "depende",
    "caso", "digamos",
    "otro", "resto",
    // EN: canonical + formal + normal + colloquial
    "print", "display", "exhibit", "present", "render", "indicate",
    "output", "show", "tell", "say", "spill", "shout", "blurt", "dish",
    "input", "ask", "request", "prompt", "query", "gimme", "cough_up",
    "if", "in_case_that", "provided_that", "given_that", "when", "suppose", "assuming",
    "else", "if_not", "or_else",
    "end", "finish", "done", "over", "enough", "finito",
    "while", "whilst", "as_long_as", "keep_going",
    "function", "procedure", "routine", "sub", "method",
    "return", "give_back", "hand_back", "yield",
    "and", "with",
    "or",
    "not", "aint",
    "equal", "equals", "is", "is_equal_to", "comes_to",
    "plus", "add",
    "minus", "subtract", "deduct", "take_away",
    "times", "multiply", "multiplied_by",
    "divide", "divided_by", "over",
    "is_greater_than", "greater_than", "bigger_than", "exceeds",
    "is_less_than", "less_than", "smaller_than",
    "is_different", "is_not", "differ_from",
    "is_greater_or_equal", "is_less_or_equal",
    "true", "right", "yup",
    "false", "wrong", "nope",
    "list", "collection", "group", "bunch", "pile", "array", "set",
    "empty", "blank",
    "element", "item", "member", "entry", "cell",
    "first", "head",
    "last", "tail",
    "length", "size", "count",
    "append", "attach", "stick_in", "toss_in", "push",
    "remove", "delete", "drop", "take_out", "erase",
    "of", "from",
    "to",
    "in", "inside", "within",
    "record", "card", "file", "packet", "struct",
    "put", "place", "set", "assign", "store",
    "pointer", "finger",
    "stop", "halt",
    "continue", "carry_on", "go_on",
    "for_each", "each", "for_every",
    "as",
    "match", "switch", "depending_on",
    "case", "say",
    "other", "otherwise", "default",
    "enseñar", "exponer", "exhibir", "presentar", "desplegar",
    "indicar", "muestra", "enseña", "mira", "canta", "suelta", "chivate",
    "pregona", "anuncia", "declara", "revela", "descubre", "grita", "cuenta",
    "relata", "narra", "detalla", "pinta", "dibuja", "escribe", "imprime",
    "publica", "emite", "proyecta", "refleja", "escupe", "vomita", "write",
    "draw", "paint", "announce", "proclaim", "declare", "reveal", "narrate",
    "relate", "detail", "publish", "emit", "project", "type", "echo", "log",
    "dump", "spew", "vomit", "pide", "atiende", "recibe", "recoge", "acepta",
    "toma", "agarra", "pilla", "cuentame", "cuéntame", "get", "read", "scan",
    "fetch", "collect", "receive", "accept", "grab", "tell_me", "si_acaso",
    "por_si", "por_si_acaso", "puesto_que", "ya_que", "a_ver_si", "y_si",
    "lest", "on_condition_that", "in_the_event_that", "what_if",
    "de_otra_forma", "de_otra_manera", "en_su_defecto", "instead",
    "alternatively", "failing_that", "terminado", "terminada", "acabado",
    "acabada", "concluido", "cerrado", "punto_final", "se_termino",
    "hasta_aqui", "colorin_colorado", "he_dicho", "caso_cerrado", "amen",
    "fin_transmision", "finished", "completed", "concluded", "closed",
    "period", "mic_drop", "case_closed", "over_and_out",
    "end_of_transmission", "thats_all", "the_end", "cut", "en_bucle",
    "en_loop", "dale_dale", "vamos", "arre", "loop", "go_go", "faena",
    "chamba", "laburo", "curro", "mision", "misión", "encargo", "cometido",
    "subrutina", "proceso", "job", "chore", "gig", "duty", "errand",
    "operation", "func", "def", "proc", "regresa", "increased_by", "up_by",
    "sustrae", "descuenta", "decreased_by", "down_by", "x", "reparte",
    "split", "gana_a", "pierde_contra", "empata_con", "pasa_de",
    "no_pasa_de", "rebasa", "beats", "loses_to", "ties_with", "surpasses",
    "tops", "es_lo_mismo", "matches", "reads", "sip", "positivo",
    "afirmativo", "yep", "yeah", "uh_huh", "correcto", "correcta", "exacto",
    "exacta", "correct", "incorrect", "exact", "precisely", "negativo",
    "ni_a_palos", "nanai", "negative", "no_sir", "serie", "sucesion",
    "sucesión", "tanda", "ristra", "retahila", "retahíla", "manojo",
    "monton", "montón", "fila", "hilera", "lineup", "roster", "series",
    "sequence", "succession", "batch", "row", "queue", "chain", "string",
    "hueca", "zilch", "zip", "nada", "trozo", "pedazo", "cacho",
    "fragmento", "eslabon", "unidad", "componente", "chunk", "piece", "bit",
    "fragment", "link", "unit", "component", "thing", "numero_uno",
    "número_uno", "campeon", "campeón", "ganador", "inicial", "number_one",
    "champ", "champion", "winner", "initial", "first_off", "colista",
    "farolillo", "farolillo_rojo", "ultimo_mono", "perdedor", "dead_last",
    "loser", "caboose", "medida", "extension", "extensión", "measurement",
    "extent", "span", "incorpora", "integra", "inyecta", "anexa", "adjunta",
    "inject", "incorporate", "integrate", "extrae", "arranca", "desecha",
    "tira", "bota", "expulsa", "extract", "yank", "toss", "chuck", "ditch",
    "discard", "out_of", "into", "foreach", "uno_a_uno", "one_by_one",
    "cajon", "cajón", "carpeta", "formulario", "folder", "form", "binder",
    "slip", "planta", "deposita", "deja", "lay", "stick", "leave", "deposit",
    "indicador", "señalador", "flecha", "indicator", "cursor", "frenazo",
    "quieto", "para_ya", "freeze", "hold_on", "whoa", "adelante", "palante",
    "sigue_sigue", "onward", "onwards", "proceed", "o_bien", "nada_de",
    "ni_de_broma", "nah", "no_way", "ni_muerto",
    "pisa", "encima", "overwrite", "overprint", "rewrite",
    "limpiar", "limpia", "clear", "cls", "tablero", "board",
    "muro", "wall", "moneda", "coin", "meta", "goal",
    "lienzo", "canvas", "marca", "mark", "plot", "stamp", "sella", "marcar",
    "lee", "leer", "peek", "chusmea", "consulta", "pared", "tapia", "muralla",
    "tapiar", "amurallar", "destino", "llegada", "despeja", "wipe", "pizarra",
    "imprimir", "pisar", "estadisticas", "esperar", "espera", "aguarda", "wait",
    "azar", "aleatorio",
    "comprobar", "prueba", "test", "verifica", "comprueba", "asegurate",
    "check", "verify", "assert", "ensure",
    "y_bit", "bit_and", "and_bit", "o_bit", "bit_or", "or_bit",
    "xor", "bit_xor", "exclusivo_o",
    "desplaza_izquierda", "shift_left", "shl",
    "desplaza_derecha", "shift_right", "shr",
    "es_equivalente_a", "equivalente_a", "is_equivalent_to", "equivalent_to",
    "conectar", "conecta", "conectate", "connect",
    "enviar", "envia", "manda", "send",
    "recibir", "recibe", "receive", "recv",
    "desconectar", "desconecta", "cuelga", "disconnect",
    "son", "are", "the", "an", "del", "al",
    "tick", "ticks", "turbo", "tiempo", "delta",
    "menor", "mayor", "distinto", "diferente", "equivalente"
  ];
  var KW = {};
  for (var k = 0; k < KEYWORDS.length; k++) KW[KEYWORDS[k]] = true;

  var OPENERS = {
    en_caso_de_que: 1, si: 1, en_el_caso_de_que: 1, siempre_que: 1, dado_que: 1,
    si_es_que: 1, cuando: 1,
    mientras: 1, dale: 1,
    funcion: 1, procedimiento: 1, rutina: 1,
    por_cada: 1, cada: 1,
    segun: 1, depende: 1,
    if: 1, in_case_that: 1, provided_that: 1, given_that: 1, when: 1,
    suppose: 1, assuming: 1,
    while: 1, whilst: 1, as_long_as: 1, keep_going: 1,
    function: 1, procedure: 1, routine: 1, sub: 1, method: 1,
    for_each: 1, each: 1, for_every: 1,
    match: 1, switch: 1, depending_on: 1,
    tick: 1, ticks: 1, fps: 1, fotogramas: 1, fotograma: 1, ritmo: 1,
    tps: 1, tiempo: 1, cuadro: 1, cuadros: 1, frames: 1, framerate: 1, rate: 1,
    si_acaso: 1, por_si: 1, por_si_acaso: 1, puesto_que: 1, ya_que: 1,
    a_ver_si: 1, y_si: 1, lest: 1, on_condition_that: 1,
    in_the_event_that: 1, what_if: 1,
    en_bucle: 1, en_loop: 1, dale_dale: 1, vamos: 1, arre: 1, loop: 1, go_go: 1,
    faena: 1, chamba: 1, laburo: 1, curro: 1, mision: 1, encargo: 1,
    cometido: 1, subrutina: 1, proceso: 1, job: 1, chore: 1, gig: 1,
    duty: 1, errand: 1, operation: 1, func: 1, def: 1, proc: 1,
    uno_a_uno: 1, one_by_one: 1, foreach: 1,
    comprobar: 1, prueba: 1, test: 1, verifica: 1, comprueba: 1,
    asegurate: 1, check: 1, verify: 1, assert: 1, ensure: 1
  };
  var CLOSERS = { fin: 1, final: 1, termina_aqui: 1, se_acabo: 1, basta: 1,
    listo: 1, ya: 1, end: 1, finish: 1, done: 1, over: 1, enough: 1, finito: 1,
    terminado: 1, terminada: 1, acabado: 1, acabada: 1, concluido: 1,
    cerrado: 1, punto_final: 1, se_termino: 1, hasta_aqui: 1,
    colorin_colorado: 1, he_dicho: 1, caso_cerrado: 1, amen: 1,
    fin_transmision: 1, finished: 1, completed: 1, concluded: 1, closed: 1,
    period: 1, mic_drop: 1, case_closed: 1, over_and_out: 1,
    end_of_transmission: 1, thats_all: 1, the_end: 1, cut: 1 };

  // Enmascara textos "..." (con "" escapada) con espacios, conservando indices.
  function maskStrings(line) {
    var out = "", i = 0, n = line.length, inStr = false;
    while (i < n) {
      var c = line[i];
      if (!inStr) {
        if (c === '"') { inStr = true; out += " "; i++; }
        else { out += c; i++; }
      } else {
        if (c === '"') {
          if (i + 1 < n && line[i + 1] === '"') { out += "  "; i += 2; }
          else { inStr = false; out += " "; i++; }
        } else { out += " "; i++; }
      }
    }
    return out;
  }

  // Quita comentarios |...| (parejas; cola sin cerrar hasta fin de linea).
  // Devuelve {code, pipes}.
  function stripComments(masked) {
    var out = masked.split(""), pos = [], i;
    for (i = 0; i < masked.length; i++) if (masked[i] === "|") pos.push(i);
    for (i = 0; i + 1 < pos.length; i += 2) {
      for (var j = pos[i]; j <= pos[i + 1]; j++) out[j] = " ";
    }
    if (pos.length % 2 === 1) {
      for (var q = pos[pos.length - 1]; q < out.length; q++) out[q] = " ";
    }
    return { code: out.join(""), pipes: pos.length };
  }

  function words(code) {
    var m = code.match(/[A-Za-z_áéíóúñüÁÉÍÓÚÑÜ]+/g);
    return m || [];
  }

  // Guion-bajo = espacio (mas largas primero). Igual que el driver Nim.
  var REGLAS = [
    ["en el caso de que", "en_caso_de_que"],
    ["is greater or equal", "es_mayor_o_igual"],
    ["is less or equal", "es_menor_o_igual"],
    ["es mas grande que", "es_mayor_que"],
    ["es mas chico que", "es_menor_que"],
    ["es mas pequeno que", "es_menor_que"],
    ["es mayor o igual", "es_mayor_o_igual"],
    ["es menor o igual", "es_menor_o_igual"],
    ["es igual a", "es_igual_a"], ["is equal to", "es_igual_a"],
    ["en caso de que", "en_caso_de_que"], ["de lo contrario", "sino"],
    ["en caso contrario", "sino"], ["en otro caso", "sino"],
    ["por cada", "por_cada"], ["termina aqui", "fin"],
    ["in case that", "en_caso_de_que"], ["for each", "por_cada"],
    ["for every", "por_cada"], ["take away", "menos"],
    ["take out", "quitar"], ["toss in", "agregar"], ["stick in", "agregar"],
    ["give back", "devolver"], ["hand back", "devolver"],
    ["carry on", "sigue"], ["go on", "sigue"], ["depending on", "segun"],
    ["divided by", "entre"], ["dividido entre", "entre"],
    ["dividido por", "entre"], ["multiplied by", "por"],
    ["is greater than", "es_mayor_que"], ["is less than", "es_menor_que"],
    ["is different", "es_distinto_de"], ["differ from", "es_distinto_de"],
    ["as long as", "mientras"], ["provided that", "en_caso_de_que"],
    ["given that", "en_caso_de_que"], ["siempre que", "en_caso_de_que"],
    ["dado que", "en_caso_de_que"], ["si es que", "en_caso_de_que"],
    ["mas grande que", "es_mayor_que"], ["mas chico que", "es_menor_que"],
    ["mas pequeno que", "es_menor_que"], ["no llega a", "es_menor_que"],
    ["mayor que", "es_mayor_que"], ["menor que", "es_menor_que"],
    ["distinto de", "es_distinto_de"], ["diferente de", "es_distinto_de"],
    ["greater than", "es_mayor_que"], ["bigger than", "es_mayor_que"],
    ["less than", "es_menor_que"], ["smaller than", "es_menor_que"],
    ["is not equal", "es_distinto_de"], ["is not", "es_distinto_de"], ["is not equal", "es_distinto_de"],
    ["dentro de", "en"],
    ["es mayor que", "es_mayor_que"], ["es menor que", "es_menor_que"],
    ["are greater than", "es_mayor_que"], ["are less than", "es_menor_que"],
    ["are different from", "es_distinto_de"], ["different to", "es_distinto_de"],
    ["are equal to", "igual"], ["are equal", "igual"],
    ["es mayor a", "es_mayor_que"], ["es menor a", "es_menor_que"],
    ["mayor a", "es_mayor_que"], ["menor a", "es_menor_que"],
    ["es distinto a", "es_distinto_de"], ["distinto a", "es_distinto_de"],
    ["diferente a", "es_distinto_de"],
    ["equivalent to", "es_equivalente_a"], ["is equivalent to", "es_equivalente_a"],
    ["are equivalent to", "es_equivalente_a"],
    ["es distinto de", "es_distinto_de"],
    ["es diferente de", "es_distinto_de"],
    ["no es igual", "es_distinto_de"],
    ["es igual", "igual"], ["igual a", "igual"], ["is equal", "es_igual_a"],
    ["equal to", "igual"], ["se acabo", "fin"]
  ];
  function juntar(ws) {
    var out = [], i = 0;
    while (i < ws.length) {
      var hecho = false;
      for (var r = 0; r < REGLAS.length; r++) {
        var partes = REGLAS[r][0].split(" ");
        if (i + partes.length <= ws.length) {
          var ok = true;
          for (var k = 0; k < partes.length; k++) {
            if (ws[i + k] !== partes[k]) { ok = false; break; }
          }
          if (ok) { out.push(REGLAS[r][1]); i += partes.length; hecho = true; break; }
        }
      }
      if (!hecho) { out.push(ws[i]); i++; }
    }
    return out;
  }

  // Cuenta la familia igual (multi-palabra primero, para no contar doble).
  var IGUALES = { igual: 1, es: 1, son: 1, vale: 1, equivale_a: 1, equal: 1,
    equals: 1, is: 1, are: 1, comes_to: 1, es_lo_mismo: 1, matches: 1, reads: 1 };
  function countIgual(ws, code) {
    var n = 0, i;
    for (i = 0; i < ws.length; i++) {
      if (ws[i] === "es_igual_a" || ws[i] === "is_equal_to") continue;
      if (IGUALES[ws[i]]) n++;
    }
    for (i = 0; i < code.length; i++) if (code[i] === "=") n++;
    return n;
  }

  // lintSource(src) -> [{line, col, code, level, msg}]
  function lintSource(src) {
    var issues = [], depth = 0;
    var lines = String(src).split(/\r?\n/), i, ws;
    for (i = 0; i < lines.length; i++) {
      var line = lines[i], ln = i + 1;
      var masked = maskStrings(line);
      var st = stripComments(masked);
      var code = st.code;
      if (st.pipes % 2 === 1) {
        issues.push({ line: ln, col: line.length, code: "E006", level: "aviso",
          msg: "barra | sin cerrar: el comentario llega hasta fin de linea" });
      }
      if (code.replace(/\s/g, "") === "") continue;
      var trimmed = code.replace(/\s+$/g, "");
      var m0 = code.match(/[A-Za-z_áéíóúñüÁÉÍÓÚÑÜ]+/);
      var w0 = m0 ? m0[0] : "";
      var ws0 = words(code);
      var esListaReg = ws0.length >= 5 && /^[A-ZÁÉÍÓÚÑÜ]/.test(ws0[0]) &&
        (ws0[1] === "igual" || ws0[1] === "equal" || ws0[1] === "es" || ws0[1] === "vale" ||
         ws0[1] === "equivale_a" || ws0[1] === "equals" || ws0[1] === "is") &&
        (ws0[2] === "lista" || ws0[2] === "Lista" || ws0[2] === "list") &&
        (ws0[3] === "de" || ws0[3] === "of" || ws0[3] === "from") &&
        (ws0[4] === "registros" || ws0[4] === "registro" || ws0[4] === "records" || ws0[4] === "record");
      var lastCh = trimmed.charAt(trimmed.length - 1);
      var esBloquePuntos = (lastCh === ":" &&
        (w0 === "registro" || w0 === "record" || w0 === "estadisticas")) ||
        (esListaReg && (lastCh === ":" || lastCh === "."));
      if (trimmed.charAt(trimmed.length - 1) !== "." && !esBloquePuntos) {
        issues.push({ line: ln, col: trimmed.length + 1, code: "E001", level: "error",
          msg: "falta el punto final" });
      }
      ws = juntar(words(code));
      var opens = 0, closes = 0, ci = -1, j;
      for (j = 0; j < ws.length; j++) {
        if (OPENERS[ws[j]]) opens++;
        if (CLOSERS[ws[j]]) { closes++; if (ci < 0) ci = code.indexOf(ws[j]); }
      }
      depth += opens - closes;
      if (esBloquePuntos) depth++;
      if (depth < 0) {
        issues.push({ line: ln, col: (ci < 0 ? 1 : ci + 1), code: "E002", level: "error",
          msg: "fin sin bloque que cerrar" });
        depth = 0;
      }
      if (countIgual(ws, code) > 1) {
        issues.push({ line: ln, col: 1, code: "E004", level: "error",
          msg: "un igual por linea: se escribe en dos lineas" });
      }
    }
    if (depth > 0) {
      issues.push({ line: lines.length, col: 1, code: "E002", level: "error",
        msg: "falta(n) " + depth + " fin: hay bloque(s) sin cerrar" });
    }
    return issues;
  }

  g.ComaLint = { lintSource: lintSource, keywords: KEYWORDS };
})(typeof window !== "undefined" ? window : global);
