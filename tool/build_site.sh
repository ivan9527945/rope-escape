#!/bin/sh
# Builds the brand site into output/site: the Windows 95 shell from site/ plus
# the Flutter web build served under play/.
#   tool/build_site.sh            # site served at the domain root
#   tool/build_site.sh /rope/     # site served under a sub-path (e.g. GitHub Pages)
set -eu
cd "$(dirname "$0")/.."
BASE="${1:-/}"
case "$BASE" in */) ;; *) BASE="$BASE/";; esac
flutter build web --release --base-href "${BASE}play/"
rm -rf output/site
mkdir -p output/site
cp -R site/. output/site/
cp -R build/web output/site/play
echo "site ready: output/site  (preview: python3 -m http.server -d output/site 8080)"
