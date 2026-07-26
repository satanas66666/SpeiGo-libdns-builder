#!/usr/bin/env bash
set -Eeuo pipefail

API="${ANDROID_API:-21}"
GOARM_VALUE="${GOARM_VALUE:-7}"
DNSTT_REPO="${DNSTT_REPO:-https://github.com/Mygod/dnstt.git}"
DNSTT_REF="${DNSTT_REF:-plugin}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${SRC_DIR:-$ROOT_DIR/.build/dnstt}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || die "Falta git"
command -v go >/dev/null 2>&1 || die "Falta Go 1.24 o superior"
command -v readelf >/dev/null 2>&1 || die "Falta readelf"
command -v file >/dev/null 2>&1 || die "Falta file"
command -v strings >/dev/null 2>&1 || die "Falta strings"
command -v sha256sum >/dev/null 2>&1 || die "Falta sha256sum"

GO_VERSION="$(go env GOVERSION | sed 's/^go//')"
GO_MAJOR="${GO_VERSION%%.*}"
GO_MINOR_TMP="${GO_VERSION#*.}"
GO_MINOR="${GO_MINOR_TMP%%.*}"
if (( GO_MAJOR < 1 || (GO_MAJOR == 1 && GO_MINOR < 24) )); then
  die "Se requiere Go 1.24 o superior; encontrado: $GO_VERSION"
fi

find_ndk() {
  local candidate
  for candidate in \
    "${ANDROID_NDK_ROOT:-}" \
    "${ANDROID_NDK_HOME:-}" \
    "${ANDROID_HOME:-}/ndk/27.3.13750724" \
    "${ANDROID_SDK_ROOT:-}/ndk/27.3.13750724"; do
    if [[ -n "$candidate" && -d "$candidate/toolchains/llvm/prebuilt" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  for candidate in \
    "${ANDROID_HOME:-}/ndk/"* \
    "${ANDROID_SDK_ROOT:-}/ndk/"*; do
    if [[ -d "$candidate/toolchains/llvm/prebuilt" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

NDK_ROOT="$(find_ndk)" || die "No se encontró Android NDK. Define ANDROID_NDK_ROOT."

HOST_DIR=""
for host in linux-x86_64 linux-aarch64 darwin-x86_64 darwin-arm64 windows-x86_64; do
  if [[ -d "$NDK_ROOT/toolchains/llvm/prebuilt/$host" ]]; then
    HOST_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/$host"
    break
  fi
done
[[ -n "$HOST_DIR" ]] || die "No se encontró un toolchain ejecutable dentro del NDK."

CC="$HOST_DIR/bin/armv7a-linux-androideabi${API}-clang"
STRIP="$HOST_DIR/bin/llvm-strip"
READELF_NDK="$HOST_DIR/bin/llvm-readelf"

[[ -x "$CC" ]] || die "No existe el compilador API ${API}: $CC"

rm -rf "$SRC_DIR"
mkdir -p "$(dirname "$SRC_DIR")" "$OUT_DIR"

git clone --depth 1 --branch "$DNSTT_REF" "$DNSTT_REPO" "$SRC_DIR"

pushd "$SRC_DIR" >/dev/null
go mod download

export GOOS=android
export GOARCH=arm
export GOARM="$GOARM_VALUE"
export CGO_ENABLED=1
export CC

go build \
  -trimpath \
  -buildmode=pie \
  -ldflags='-s -w -buildid=' \
  -o "$OUT_DIR/libdns.so" \
  ./dnstt-client
popd >/dev/null

chmod 0755 "$OUT_DIR/libdns.so"
if [[ -x "$STRIP" ]]; then
  "$STRIP" --strip-unneeded "$OUT_DIR/libdns.so" || true
fi

READELF_BIN="$READELF_NDK"
[[ -x "$READELF_BIN" ]] || READELF_BIN="$(command -v readelf)"

ANDROID_API="$API" READELF_BIN="$READELF_BIN" \
  "$ROOT_DIR/scripts/validar_libdns_arm32.sh" "$OUT_DIR/libdns.so" \
  | tee "$OUT_DIR/VALIDACION_LIBDNS.txt"

(
  cd "$OUT_DIR"
  sha256sum libdns.so > SHA256SUMS.txt
)

printf '\nCOMPILACIÓN TERMINADA\n'
printf 'Archivo: %s\n' "$OUT_DIR/libdns.so"
cat "$OUT_DIR/SHA256SUMS.txt"
