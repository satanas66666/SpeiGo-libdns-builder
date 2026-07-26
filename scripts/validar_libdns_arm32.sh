#!/usr/bin/env bash
set -Eeuo pipefail

BIN="${1:-}"
[[ -n "$BIN" && -f "$BIN" ]] || {
  echo "Uso: $0 /ruta/libdns.so" >&2
  exit 2
}

READELF_BIN="${READELF_BIN:-readelf}"
command -v "$READELF_BIN" >/dev/null 2>&1 || {
  echo "No se encontró readelf/llvm-readelf" >&2
  exit 2
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$READELF_BIN" -h "$BIN" > "$TMP/header.txt"
"$READELF_BIN" -l "$BIN" > "$TMP/program.txt"
"$READELF_BIN" -d "$BIN" > "$TMP/dynamic.txt" 2>/dev/null || true
file "$BIN" > "$TMP/file.txt"
strings "$BIN" > "$TMP/strings.txt"

fail=0
check() {
  local label="$1"
  shift
  if "$@"; then
    printf 'OK   %s\n' "$label"
  else
    printf 'FALLO %s\n' "$label" >&2
    fail=1
  fi
}

check "ELF de 32 bits" grep -Eq 'Class:[[:space:]]+ELF32' "$TMP/header.txt"
check "Little-endian" grep -Eq 'Data:[[:space:]]+.*little endian' "$TMP/header.txt"
check "Arquitectura ARM" grep -Eq 'Machine:[[:space:]]+ARM' "$TMP/header.txt"

# llvm-readelf puede mostrar EABI5 solo como 0x5000200 (equivale a 0x05000200).
# El byte alto 0x05 identifica ARM EABI versión 5.
check "EABI5" grep -Eqi \
  'Flags:.*(EABI5|Version5 EABI|0x0?5[0-9a-f]{6})' \
  "$TMP/header.txt"

check "PIE / ET_DYN" grep -Eq 'Type:[[:space:]]+DYN' "$TMP/header.txt"
check "No es AArch64" bash -c "! grep -Eqi 'AArch64|ARM aarch64' '$TMP/header.txt' '$TMP/file.txt'"
check "Nombre/uso dnstt-client" grep -q 'dnstt-client' "$TMP/strings.txt"
check "Opción -udp" grep -q -- '-udp' "$TMP/strings.txt"
check "Opción -doh" grep -q -- '-doh' "$TMP/strings.txt"
check "Opción -dot" grep -q -- '-dot' "$TMP/strings.txt"
check "Opción -pubkey" grep -q -- '-pubkey' "$TMP/strings.txt"
check "Opción -pubkey-file" grep -q -- '-pubkey-file' "$TMP/strings.txt"

printf '\n--- file ---\n'
cat "$TMP/file.txt"
printf '\n--- Cabecera ELF ---\n'
grep -E 'Class:|Data:|Type:|Machine:|Flags:' "$TMP/header.txt" || true
printf '\n--- Intérprete y segmentos ---\n'
grep -E 'Requesting program interpreter|INTERP|LOAD|GNU_STACK|GNU_RELRO' "$TMP/program.txt" || true
printf '\n--- Dependencias dinámicas ---\n'
grep -E 'NEEDED|SONAME|FLAGS_1' "$TMP/dynamic.txt" || true
printf '\nSHA-256: '
sha256sum "$BIN" | awk '{print $1}'

if (( fail != 0 )); then
  printf '\nRESULTADO: NO APTO PARA SPEIGO ARM32\n' >&2
  exit 1
fi

printf '\nRESULTADO: APTO ESTÁTICAMENTE PARA SPEIGO ARM32/API %s\n' "${ANDROID_API:-21}"
printf 'Prueba final obligatoria: ejecutar en un dispositivo real ARM32 con Android 5 o superior.\n'
