#!/usr/bin/env bash
# Builds the single-file playable prototype.
#
# The engine is compiled from the same Dart source the Flutter app uses, then
# inlined so the page has no external requests and can be opened from a file,
# a static host, or a Claude artifact.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
out="$here/minedoku-prototype.html"

echo "Compiling the Dart engine to JavaScript..."
(cd "$root/engine" && dart compile js -O2 tool/web_bridge.dart -o build/engine.js)

echo "Inlining into $out ..."
python3 - "$here/index.template.html" "$root/engine/build/engine.js" "$out" <<'PY'
import sys

template_path, engine_path, out_path = sys.argv[1:4]

with open(template_path, encoding="utf-8") as f:
    template = f.read()
with open(engine_path, encoding="utf-8") as f:
    engine = f.read()

marker = "/*__ENGINE__*/"
if marker not in template:
    raise SystemExit(f"marker {marker} missing from template")

# str.replace would treat backslashes in the compiled JS as literal text, which
# is what we want, so this is safe; re.sub would not be.
with open(out_path, "w", encoding="utf-8") as f:
    f.write(template.replace(marker, engine))
PY

echo "Done: $out"
