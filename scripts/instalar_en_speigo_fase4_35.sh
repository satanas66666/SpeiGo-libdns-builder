#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_BIN="${SOURCE_BIN:-$ROOT_DIR/out/libdns.so}"

[[ -n "$PROJECT" && -d "$PROJECT/app/src/main" ]] || {
  echo "Uso: $0 /ruta/proyecto/SpeiGo_VPN" >&2
  exit 2
}
[[ -f "$SOURCE_BIN" ]] || {
  echo "No existe $SOURCE_BIN. Compila primero." >&2
  exit 2
}

ARM32_DIR="$PROJECT/app/src/main/jniLibs/armeabi-v7a"
ARM64_BIN="$PROJECT/app/src/main/jniLibs/arm64-v8a/libdns.so"
ARM32_BIN="$ARM32_DIR/libdns.so"

[[ -f "$ARM64_BIN" ]] || {
  echo "FALLO: no existe el libdns.so ARM64 actual: $ARM64_BIN" >&2
  exit 1
}

BEFORE="$(sha256sum "$ARM64_BIN" | awk '{print $1}')"
mkdir -p "$ARM32_DIR"

ANDROID_API=21 "$ROOT_DIR/scripts/validar_libdns_arm32.sh" "$SOURCE_BIN"

install -m 0755 "$SOURCE_BIN" "$ARM32_BIN"

AFTER="$(sha256sum "$ARM64_BIN" | awk '{print $1}')"
[[ "$BEFORE" == "$AFTER" ]] || {
  echo "FALLO CRÍTICO: cambió el SHA-256 del ARM64." >&2
  exit 1
}

printf '\nINSTALACIÓN COMPLETADA\n'
printf 'ARM32 agregado: %s\n' "$ARM32_BIN"
printf 'ARM32 SHA-256: %s\n' "$(sha256sum "$ARM32_BIN" | awk '{print $1}')"
printf 'ARM64 conservado: %s\n' "$ARM64_BIN"
printf 'ARM64 SHA-256 sin cambios: %s\n' "$AFTER"

printf '\nATENCIÓN:\n'
printf 'La Fase 4.35 contiene una guarda que bloquea SlowDNS ARM32 por ausencia del binario.\n'
printf 'Actualiza esa guarda para comprobar la existencia del archivo en vez de bloquear toda la ABI.\n'
