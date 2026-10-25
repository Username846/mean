#!/bin/bash
# Rebuilds the browser version into docs/ (served by GitHub Pages).
# Needs Godot 4.7.2 on PATH as `godot` and the 4.7.2 export templates installed.
set -e
cd "$(dirname "$0")/.."
godot --headless --import
godot --headless --export-release "Web" docs/index.html
touch docs/.nojekyll docs/.gdignore
echo "Exported to docs/"
