#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_root=${PZ_MOD_TOOLS_ROOT:-"$root_dir/../PzModTools"}

lua "$root_dir/tests/test_runner.lua"
python3 "$tools_root/validators/validate_translations.py" --root "$root_dir"
python3 "$root_dir/tools/validate_localization.py"
