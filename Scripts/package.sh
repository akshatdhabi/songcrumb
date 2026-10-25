#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_output="${1:?Choose a destination directory outside the source checkout}"
mkdir -p "$task_output"
task_output="$(cd "$task_output" && pwd)"
if [[ "$task_output/" == "$task_root/"* ]]; then
  echo 'Choose an output directory outside the source checkout.' >&2
  exit 1
fi
cd "$task_root"
python3 Scripts/check_public.py
# Only tracked files can enter the source archive; build products and local prefs cannot.
git archive --format=zip --prefix=Songcrumb/ HEAD -o "$task_output/Songcrumb-Source.zip"
echo "Source archive: $task_output/Songcrumb-Source.zip"
