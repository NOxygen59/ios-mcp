#!/bin/zsh
# Publie le .deb construit : push de la branche ipad-ios16, release GitHub (créée ou mise à jour)
# et ajout à la source Sileo (NOxygen59/sileo-repo). Appelé automatiquement par build.sh
# après un build release rootless ; IOS_MCP_PUBLISH=0 pour ne pas publier.
#
#   scripts/publish.sh packages/com.witchan.ios-mcp_<version>_iphoneos-arm64.deb
#
# Le tag vient de la version du fichier control (1.2.8-ios16 → v1.2.8-ios16). Les notes de
# release sont dans docs/ipad-ios16/releases/<tag>.md, dont la première ligne est le titre ;
# sans ce fichier, rien n'est publié.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
REPO_DIR="${SILEO_REPO_DIR:-$ROOT/../sileo-repo}"
DEB="$1"

VERSION="$(dpkg-deb -f "$DEB" Version)"
TAG="v${VERSION}"
NOTES="$ROOT/docs/ipad-ios16/releases/${TAG}.md"
if [[ ! -f "$NOTES" ]]; then
  print "Pas de notes de release ($NOTES) : publication ignorée."
  exit 0
fi
TITLE="$(head -n 1 "$NOTES")"
BODY="$(mktemp)"
tail -n +3 "$NOTES" > "$BODY"
ASSET="${TMPDIR:-/tmp}/iOS-MCP-${VERSION}-rootless.deb"
cp -f "$DEB" "$ASSET"

print "==> Push de la branche ipad-ios16"
git -C "$ROOT" push -q fork ipad-ios16

print "==> Release ${TAG}"
if gh release view "$TAG" -R NOxygen59/ios-mcp >/dev/null 2>&1; then
  gh release edit "$TAG" -R NOxygen59/ios-mcp --title "$TITLE" --notes-file "$BODY" >/dev/null
  gh release upload "$TAG" "$ASSET" -R NOxygen59/ios-mcp --clobber
else
  gh release create "$TAG" "$ASSET" -R NOxygen59/ios-mcp --target ipad-ios16 \
    --title "$TITLE" --notes-file "$BODY" --latest
fi
rm -f "$BODY" "$ASSET"

print "==> Source Sileo"
[[ -d "$REPO_DIR/.git" ]] || git clone -q https://github.com/NOxygen59/sileo-repo.git "$REPO_DIR"
git -C "$REPO_DIR" pull -q --rebase
cp -f "$DEB" "$REPO_DIR/debs/"
git -C "$REPO_DIR" add debs
if git -C "$REPO_DIR" commit -q -m "$(basename "$DEB")"; then
  git -C "$REPO_DIR" push -q
  print "Publié : Sileo verra la mise à jour dans une minute environ."
else
  print "Sileo : ce .deb est déjà publié."
fi
print "Release : https://github.com/NOxygen59/ios-mcp/releases/tag/${TAG}"
