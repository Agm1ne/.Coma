#!/bin/sh
# ============================================================================
#  get-toolchain.sh — el usuario NO tiene que instalar nada (Linux/macOS).
#
#  Descarga el toolchain portable de LLVM (zig) y lo deja en
#  tools/toolchain/zig/ . El compilador lo encuentra solo: no hay que
#  tocar el PATH ni instalar nada en el sistema.
#
#  Es idempotente: si ya esta, no hace nada.
#
#  Uso:  sh tools/get-toolchain.sh
# ============================================================================
set -e
cd "$(dirname "$0")/.."

TOOLCHAIN="$PWD/tools/toolchain"
ZIGVER=0.17.0

case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  *) echo "[MAL] arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
esac
case "$(uname -s)" in
  Darwin) OS=macos; EXT=tar.xz ;;
  Linux)  OS=linux; EXT=tar.xz ;;
  *) echo "[MAL] sistema no soportado: $(uname -s)" >&2; exit 1 ;;
esac

ZIGURL="https://ziglang.org/download/$ZIGVER/zig-$ARCH-$OS-$ZIGVER.$EXT"
case "$ARCH-$OS" in
  x86_64-linux)  ZIGSHA=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026 ;;
  aarch64-linux) ZIGSHA=9e8d11661d4ae3bd57702a3832781e23ad151dde5798e16a5ccd503f65234ff8 ;;
  x86_64-macos)  ZIGSHA=4f9a1c5269aa17ebda5e6d3c2b89d6cbf36f7d2b22a0306e9ab98f25f95529c6 ;;
  aarch64-macos) ZIGSHA=b607e9b9234790a008116ae5bdb71c6243b84b9fb42a53a9e70fde41c06c536a ;;
esac

if [ -x "$TOOLCHAIN/zig/zig" ]; then
  echo "[OK] El toolchain ya esta en tools/toolchain/zig/"
  "$TOOLCHAIN/zig/zig" version
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/4] Descargando zig $ZIGVER ($ARCH-$OS)..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$TMP/zig.$EXT" "$ZIGURL"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$TMP/zig.$EXT" "$ZIGURL"
else
  echo "[MAL] hace falta curl o wget" >&2; exit 1
fi

echo "[2/4] Verificando SHA256..."
if command -v sha256sum >/dev/null 2>&1; then
  GOT="$(sha256sum "$TMP/zig.$EXT" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  GOT="$(shasum -a 256 "$TMP/zig.$EXT" | cut -d' ' -f1)"
else
  echo "[MAL] hace falta sha256sum o shasum" >&2; exit 1
fi
if [ "$GOT" != "$ZIGSHA" ]; then
  echo "[MAL] SHA256 distinto al esperado." >&2
  echo "  esperado: $ZIGSHA" >&2
  echo "  obtenido: $GOT" >&2
  exit 1
fi
echo "      SHA256 ok."

echo "[3/4] Extrayendo en tools/toolchain/ ..."
mkdir -p "$TOOLCHAIN"
rm -rf "$TOOLCHAIN/zig"
tar -xf "$TMP/zig.$EXT" -C "$TOOLCHAIN"
for d in "$TOOLCHAIN"/zig-*; do
  [ -d "$d" ] && mv "$d" "$TOOLCHAIN/zig"
done

if [ ! -x "$TOOLCHAIN/zig/zig" ]; then
  echo "[MAL] no se encontro zig tras extraer." >&2
  exit 1
fi

echo "[4/4] Listo."
echo
"$TOOLCHAIN/zig/zig" version
echo
echo "Ya puedes compilar .coma sin haber instalado nada:"
echo "    nim/coma.exe juego/cripta.coma"
echo
