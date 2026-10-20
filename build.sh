#!/bin/zsh
# Construit le paquet .deb d'iOS MCP.
#
# Utilisation :
#   ./build.sh                       # menu interactif
#   ./build.sh rootless release      # sans questions
#   ./build.sh roothide debug
#
# Variables utiles :
#   THEOS=~/theos                    # emplacement de Theos (défaut : ~/theos)
#   IOS_MCP_NO_PADDLE=1              # ignore PaddleOCR (l'OCR utilise alors Apple Vision)
#   IOS_MCP_PUBLISH=0                # ne publie pas (sinon un build release rootless est publié
#                                    # sur GitHub et Sileo par scripts/publish.sh)
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
export THEOS="${THEOS:-$HOME/theos}"

# Theos refuse les chemins contenant des espaces : on compile dans une copie temporaire.
if [[ "$ROOT_DIR" == *" "* && -z "${IOS_MCP_BUILD_COPY:-}" ]]; then
  BUILD_COPY="${TMPDIR:-/tmp}"
  BUILD_COPY="${BUILD_COPY%/}/ios-mcp-build"
  if [[ "$BUILD_COPY" == *" "* ]]; then
    BUILD_COPY="/tmp/ios-mcp-build"
  fi
  print "Le chemin du projet contient des espaces ; compilation dans ${BUILD_COPY}"
  mkdir -p "$BUILD_COPY"
  rsync -a --delete --exclude .git --exclude packages --exclude .theos "${ROOT_DIR}/" "${BUILD_COPY}/"
  mkdir -p "${ROOT_DIR}/packages"
  IOS_MCP_BUILD_COPY=1 IOS_MCP_SOURCE_DIR="$ROOT_DIR" IOS_MCP_COPY_BACK="${ROOT_DIR}/packages" \
    zsh "${BUILD_COPY}/build.sh" "$@"
  exit 0
fi

cd "$ROOT_DIR"

# Le Theos officiel n'a pas roothide.h : on fournit le stub pour rootful/rootless.
if [[ ! -f "$THEOS/vendor/include/roothide.h" ]]; then
  export ADDITIONAL_CFLAGS="${ADDITIONAL_CFLAGS:-} -I${ROOT_DIR}/third_party/roothide-stub/include"
fi

OUTPUT_DIR="${ROOT_DIR}/packages"
mkdir -p "$OUTPUT_DIR"

latest_package_after() {
  local stamp_file="$1"
  find "${ROOT_DIR}/packages" -maxdepth 1 -type f -name '*.deb' -newer "${stamp_file}" -print | sort | tail -n 1
}

set_scheme() {
  case "$1" in
    1|rootful|ROOTFUL)    BUILD_SCHEME="";         BUILD_SCHEME_LABEL="rootful" ;;
    2|rootless|ROOTLESS)  BUILD_SCHEME="rootless"; BUILD_SCHEME_LABEL="rootless" ;;
    3|roothide|ROOTHIDE)  BUILD_SCHEME="roothide"; BUILD_SCHEME_LABEL="roothide" ;;
    *) return 1 ;;
  esac
}

set_package_type() {
  case "$1" in
    1|release|final) BUILD_ARGS=(FINALPACKAGE=1 DEBUG=0 STRIP=1); BUILD_TYPE_LABEL="release" ;;
    2|debug|test)    BUILD_ARGS=(DEBUG=1 STRIP=0);                BUILD_TYPE_LABEL="debug" ;;
    *) return 1 ;;
  esac
}

choose_scheme() {
  while true; do
    print ""
    print "Choisis le type de jailbreak :"
    print "  1) rootful   (iOS 13–18, ex. checkra1n, unc0ver, palera1n rootful)"
    print "  2) rootless  (iOS 15–18, ex. Dopamine, palera1n rootless)"
    print "  3) roothide  (iOS 15–18, Dopamine roothide)"
    read 'choice?Numéro : '
    set_scheme "$choice" && return
    print "Choix invalide, recommence."
  done
}

choose_package_type() {
  while true; do
    print ""
    print "Choisis le type de paquet :"
    print "  1) release (optimisé)"
    print "  2) debug   (symboles, pour tester)"
    read 'choice?Numéro : '
    set_package_type "$choice" && return
    print "Choix invalide, recommence."
  done
}

build_subprojects() {
  print ""
  print "==> Compilation des sous-projets..."
  if [[ ! -f third_party/libzip-ios/lib/libzip.a && ! -f "$THEOS/lib/libzip.a" ]]; then
    print "==> libzip pour iOS absente : compilation (scripts/build_libzip_ios.sh)..."
    zsh scripts/build_libzip_ios.sh
  fi
  local scheme_env=()
  if [[ -n "$BUILD_SCHEME" ]]; then
    scheme_env=(THEOS_PACKAGE_SCHEME="$BUILD_SCHEME")
  fi
  (cd AppSync && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
  (cd AppSync/appinst && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
  (cd mcp-roothelper && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
  (cd mcp-ldid && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
  (cd mcp-root && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
  (cd mcp-logreader && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
  if [[ "${IOS_MCP_NO_PADDLE:-}" == "1" ]]; then
    print "==> PaddleOCR ignoré (IOS_MCP_NO_PADDLE=1) : l'OCR utilisera Apple Vision."
    return
  fi
  if [[ ! -f third_party/paddleocr/runtime/ios/lib/libonnxruntime.a ]]; then
    print "==> Runtime PaddleOCR absent : paquet construit sans PaddleOCR (l'OCR utilisera Apple Vision)."
    print "    Pour l'inclure, voir docs/PADDLEOCR.md."
    export IOS_MCP_NO_PADDLE=1
    return
  fi
  (cd mcp-ocr-worker && make "${scheme_env[@]}" clean && make "${scheme_env[@]}")
}

build_selected_package() {
  local stamp_file deb
  stamp_file="$(mktemp)"
  touch "$stamp_file"

  print ""
  if [[ "$BUILD_SCHEME_LABEL" == "roothide" && ! -f "$THEOS/vendor/include/roothide.h" ]]; then
    print -u2 "Le build roothide nécessite le Theos de roothide (https://github.com/roothide/theos)."
    exit 1
  fi
  print "==> Construction : ${BUILD_SCHEME_LABEL} / ${BUILD_TYPE_LABEL}"
  make clean >/dev/null
  build_subprojects
  if [[ "$BUILD_TYPE_LABEL" == "debug" ]]; then
    mkdir -p .theos/obj/debug/arm64 .theos/obj/debug/arm64e
  fi
  if [[ -n "$BUILD_SCHEME" ]]; then
    make "${BUILD_ARGS[@]}" THEOS_PACKAGE_SCHEME="$BUILD_SCHEME" package
  else
    env -u THEOS_PACKAGE_SCHEME make "${BUILD_ARGS[@]}" package
  fi

  deb="$(latest_package_after "$stamp_file")"
  rm -f "$stamp_file"

  if [[ -z "$deb" ]]; then
    print -u2 "Aucun paquet produit trouvé dans ${ROOT_DIR}/packages."
    exit 1
  fi

  if [[ -n "${IOS_MCP_COPY_BACK:-}" ]]; then
    cp -f "$deb" "${IOS_MCP_COPY_BACK}/"
    print "Paquet copié dans ${IOS_MCP_COPY_BACK}"
  fi

  print ""
  print "Construction terminée :"
  print "  ${deb}"

  # Publication automatique (GitHub + Sileo) des builds release rootless, sauf IOS_MCP_PUBLISH=0.
  if [[ "${IOS_MCP_PUBLISH:-1}" != "0" && "$BUILD_SCHEME_LABEL" == "rootless" && "$BUILD_TYPE_LABEL" == "release" ]]; then
    zsh "${IOS_MCP_SOURCE_DIR:-$ROOT_DIR}/scripts/publish.sh" "${IOS_MCP_SOURCE_DIR:-$ROOT_DIR}/packages/$(basename "$deb")"
  fi
}

if [[ $# -ge 1 ]]; then
  set_scheme "$1" || { print -u2 "Type de jailbreak inconnu : $1 (rootful|rootless|roothide)"; exit 1; }
else
  choose_scheme
fi
if [[ $# -ge 2 ]]; then
  set_package_type "$2" || { print -u2 "Type de paquet inconnu : $2 (release|debug)"; exit 1; }
else
  choose_package_type
fi
build_selected_package
