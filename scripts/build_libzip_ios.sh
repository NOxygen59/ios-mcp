#!/bin/zsh
# Compile libzip (statique, arm64, iOS 13+) pour mcp-appinst.
# Résultat : third_party/libzip-ios/lib/libzip.a (ignoré par git, à reconstruire après un clone).
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION=1.7.3   # même version que AppSync/appinst/zip.h et zipconf.h
SHA256=0e2276c550c5a310d4ebf3a2c3dfc43fb3b4602a072ff625842ad4f3238cb9cc
OUT="$ROOT_DIR/third_party/libzip-ios"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL -o "$WORK/libzip.tar.gz" "https://libzip.org/download/libzip-${VERSION}.tar.gz"
echo "${SHA256}  $WORK/libzip.tar.gz" | shasum -a 256 -c -
tar -xzf "$WORK/libzip.tar.gz" -C "$WORK"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
nice -n 15 cmake -S "$WORK/libzip-${VERSION}" -B "$WORK/build" -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_OPENSSL=OFF -DENABLE_GNUTLS=OFF \
  -DENABLE_MBEDTLS=OFF -DENABLE_COMMONCRYPTO=ON \
  -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF \
  -DCMAKE_INSTALL_PREFIX="$OUT" >/dev/null
nice -n 15 cmake --build "$WORK/build" -j 4
cmake --install "$WORK/build" >/dev/null
print "libzip ${VERSION} : $OUT/lib/libzip.a"
