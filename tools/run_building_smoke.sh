#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ "${1:-}" != create ] && [ "${1:-}" != reload ]; then
    tools_root=${PZ_MOD_TOOLS_ROOT:-"$project_dir/../PzModTools"}
    exec "$tools_root/scripts/run-smoke-save-matrix.sh" "$0" \
        neatui /tmp/SurvivorMemory-Smoke-NeatUI \
        vanilla /tmp/SurvivorMemory-Smoke-Vanilla
fi

stage=$1
cache_dir=$2
variant=$3
save_name=${4:-}
case "$variant" in
    neatui) with_neatui=1 ;;
    vanilla) with_neatui=0 ;;
    *) echo "SMOKE FAIL: variante inconnue: $variant" >&2; exit 2 ;;
esac
if [ "$stage" = create ]; then mode=building; else mode=reload; fi

game_dir=${PZ_INSTALL_DIR:-${PZ_INSTALL:-"$HOME/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"}}
neatui_dir=${NEATUI_DIR:-"$HOME/.local/share/Steam/steamapps/workshop/content/108600/3508537032/mods/NeatUI_Framework"}
mod_dir="$cache_dir/mods/SurvivorMemory"
neat_mod_dir="$cache_dir/mods/NeatUI_Framework"
console_file="$cache_dir/console.txt"
launcher="$cache_dir/SMProjectZomboid64"
launcher_config="$cache_dir/ProjectZomboid64.json"
agent_classes="$cache_dir/agent-classes"
agent_jar="$cache_dir/sm-autostart-agent.jar"

test -f "$game_dir/projectzomboid.jar" || { echo "SMOKE FAIL: installation B42 absente" >&2; exit 2; }
if [ "$with_neatui" = 1 ]; then
    test -f "$neatui_dir/42/mod.info" || { echo "SMOKE FAIL: NeatUI B42 absent" >&2; exit 2; }
fi
case "$cache_dir" in /tmp/SurvivorMemory-Smoke|/tmp/SurvivorMemory-Smoke-*) ;; *) echo "SMOKE FAIL: cache non sûr" >&2; exit 126 ;; esac

mkdir -p "$mod_dir" "$cache_dir/Screenshots" "$agent_classes"
rsync -a --delete --exclude='.git/' --exclude='test-results/' "$project_dir/" "$mod_dir/"
if [ "$with_neatui" = 1 ]; then
    mkdir -p "$neat_mod_dir"
    rsync -a --delete "$neatui_dir/" "$neat_mod_dir/"
fi
mkdir -p "$mod_dir/42/media/lua/client/DebugUIs/Scenarios"
cp "$project_dir/tools/SmokeScenario.lua" "$mod_dir/42/media/lua/client/DebugUIs/Scenarios/SurvivorMemorySmokeScenario.lua"
if [ "$mode" = reload ]; then
    test -n "$save_name" || { echo "RELOAD FAIL: nom de sauvegarde absent" >&2; exit 2; }
    printf 'SM_RELOAD_MODE = true\nSM_RELOAD_SAVE = "%s"\n' "$save_name" > "$mod_dir/42/media/lua/client/000_SurvivorMemorySmokeMode.lua"
    cp "$project_dir/tools/ReloadValidation.lua" "$mod_dir/42/media/lua/client/001_SurvivorMemoryReloadValidation.lua"
else
    if [ "$with_neatui" = 1 ]; then neat_expected=true; else neat_expected=false; fi
    printf '%s\n' 'SM_SMOKE_MODE = true' "SM_EXPECT_NEATUI = $neat_expected" > "$mod_dir/42/media/lua/client/000_SurvivorMemorySmokeMode.lua"
fi

: > "$cache_dir/mods/reset-mods-42_00.txt"
if [ "$with_neatui" = 1 ]; then
    printf '%s\n' 'VERSION = 1,' '' 'mods' '{' '    mod = NeatUI_Framework,' '    mod = SurvivorMemory,' '}' '' 'maps' '{' '    map = Muldraugh, KY,' '}' > "$cache_dir/mods/default.txt"
else
    printf '%s\n' 'VERSION = 1,' '' 'mods' '{' '    mod = SurvivorMemory,' '}' '' 'maps' '{' '    map = Muldraugh, KY,' '}' > "$cache_dir/mods/default.txt"
fi
if [ "$mode" = reload ]; then force_launch=false; result_tag=RELOAD; else force_launch=true; result_tag=SMOKE; fi
printf '%s\n' 'VERSION=1' "DebugScenario.ForceLaunch=$force_launch" > "$cache_dir/debug-options.ini"
pz_user_dir=${PZ_USER_DIR:-${PZ_HOME:-"$HOME/Zomboid"}}
if [ -f "$pz_user_dir/options.ini" ]; then
    cp "$pz_user_dir/options.ini" "$cache_dir/options.ini"
    sed -i -e 's/^fullScreen=.*/fullScreen=false/' -e 's/^borderlessWindow=.*/borderlessWindow=false/' -e 's/^width=.*/width=960/' -e 's/^height=.*/height=720/' -e 's/^focusloss=.*/focusloss=false/' "$cache_dir/options.ini"
fi

: > "$console_file"
javac -cp "$game_dir/projectzomboid.jar" -d "$agent_classes" "$project_dir/tools/SurvivorMemoryAutoStartAgent.java"
jar cfm "$agent_jar" "$project_dir/tools/smoke-agent.mf" -C "$agent_classes" .
cp "$game_dir/ProjectZomboid64" "$launcher"
cp "$game_dir/ProjectZomboid64.json" "$launcher_config"
sed -i 's/-Xmx[0-9][0-9]*m/-Xmx2304m/' "$launcher_config"
sed -i "/\"vmArgs\": \[/a\\\t\t\"-javaagent:$agent_jar\"," "$launcher_config"
if [ "$mode" = reload ]; then sed -i '/"vmArgs": \[/a\        "-Dsm.reload=true",' "$launcher_config"; fi

cd "$game_dir"
LD_LIBRARY_PATH="$game_dir/natives${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$launcher" -debug -nosound -nosteam "-cachedir=$cache_dir" > "$cache_dir/launcher.log" 2>&1 &
game_pid=$!
cleanup() { kill "$game_pid" 2>/dev/null || true; }
trap cleanup INT TERM EXIT
deadline=$(( $(date +%s) + 240 ))
result=""
while kill -0 "$game_pid" 2>/dev/null; do
    result=$(grep "\[SurvivorMemory\] $result_tag RESULT" "$console_file" | tail -n 1 || true)
    [ -z "$result" ] || break
    if [ "$(date +%s)" -ge "$deadline" ]; then echo "SMOKE FAIL: timeout" >&2; tail -n 100 "$console_file" >&2; exit 124; fi
    sleep 1
done
if [ -z "$result" ]; then echo "SMOKE FAIL: jeu terminé sans verdict" >&2; tail -n 100 "$console_file" >&2; exit 1; fi
echo "$result"
grep "\[SurvivorMemory\] $result_tag \(CHECK\|METRICS\|SAVE\|LOAD\)" "$console_file" || true
mkdir -p "$project_dir/docs/images" "$project_dir/test-results"
if [ "$with_neatui" = 1 ]; then result_file="$mode-console.txt"; else result_file="$mode-vanilla-ui-console.txt"; fi
cp "$console_file" "$project_dir/test-results/$result_file"
if [ "$mode" = building ] && [ "$with_neatui" = 1 ]; then
    if [ -f "$cache_dir/Screenshots/survivor-memory-panel.png" ]; then cp "$cache_dir/Screenshots/survivor-memory-panel.png" "$project_dir/docs/images/survivor-memory-panel.png"; fi
    if [ -f "$cache_dir/Screenshots/survivor-memory-world-map.png" ]; then cp "$cache_dir/Screenshots/survivor-memory-world-map.png" "$project_dir/docs/images/survivor-memory-world-map.png"; fi
fi
case "$result" in *'status=PASS'*) exit 0 ;; *) exit 1 ;; esac
