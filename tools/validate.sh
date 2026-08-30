#!/usr/bin/env sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for required in \
    BuildingIdentity ContainerIdentity MemoryStore TimeFormat VisitSession LocationName StatusPresentation; do
    [ -f "$root_dir/42/media/lua/shared/SurvivorMemory/$required.lua" ] \
        || fail "module partagé absent: $required"
done
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/Runtime.lua" ] || fail "runtime client absent"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/UICompat.lua" ] || fail "compatibilité UI absente"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/MemoryPanel.lua" ] || fail "UI MVP absente"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/MemoryDebugPanel.lua" ] || fail "UI debug absente"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/MemoryStatusIndicator.lua" ] || fail "indicateur mémoire absent"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/WorldMapOverlay.lua" ] || fail "overlay World Map absent"
[ -f "$root_dir/42/media/ui/SurvivorMemory/memory-status.png" ] || fail "icône mémoire absente"
if grep -q '^require=.*NeatUI_Framework' "$root_dir/mod.info" "$root_dir/42/mod.info"; then
    fail "NeatUI doit rester optionnel"
fi
if rg -n '^require "neatui_framework/' "$root_dir/42/media/lua/client/SurvivorMemory" \
    --glob '!UICompat.lua' >/dev/null; then
    fail "require NeatUI direct hors UICompat"
fi

printf 'PASS: invariants SurvivorMemory valides\n'
