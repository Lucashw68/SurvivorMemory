#!/usr/bin/env sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

same_asset() {
    source_file=$1
    deployed_file=$2
    label=$3
    [ -f "$source_file" ] || fail "asset canonique absent: $label"
    [ -f "$deployed_file" ] || fail "miroir asset absent: $label"
    cmp -s "$source_file" "$deployed_file" || fail "miroir asset désynchronisé: $label"
}

for required in \
    BuildingIdentity ContainerIdentity MemoryStore TimeFormat VisitSession LocationName StatusPresentation PlaceDesignation EmotionalMemory ImportantMemory VehicleMemory VisibleObservation Settings; do
    [ -f "$root_dir/42/media/lua/shared/SurvivorMemory/$required.lua" ] \
        || fail "module partagé absent: $required"
done
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/Runtime.lua" ] || fail "runtime client absent"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/ModOptions.lua" ] || fail "options B42 natives absentes"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/UICompat.lua" ] || fail "compatibilité UI absente"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/MemoryPanel.lua" ] || fail "UI MVP absente"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/MemoryDebugPanel.lua" ] || fail "UI debug absente"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/MemoryStatusIndicator.lua" ] || fail "indicateur mémoire absent"
[ -f "$root_dir/42/media/lua/client/SurvivorMemory/WorldMapOverlay.lua" ] || fail "overlay World Map absent"
[ -f "$root_dir/42/media/ui/SurvivorMemory/memory-status.png" ] || fail "icône mémoire absente"
[ -f "$root_dir/42/media/ui/SurvivorMemory/map-memory-marker.png" ] || fail "marqueur carte mémoire absent"
[ -f "$root_dir/42/media/ui/SurvivorMemory/map-home-marker.png" ] || fail "marqueur carte HOME absent"
[ -f "$root_dir/42/media/ui/SurvivorMemory/map-outpost-marker.png" ] || fail "marqueur carte OUTPOST absent"
[ -f "$root_dir/42/media/ui/SurvivorMemory/map-vehicle-marker.png" ] || fail "marqueur carte véhicule absent"
[ -f "$root_dir/poster.png" ] || fail "poster racine absent"
[ -f "$root_dir/icon.png" ] || fail "icône de mod racine absente"
[ -f "$root_dir/42/poster.png" ] || fail "poster B42 absent"
[ -f "$root_dir/42/icon.png" ] || fail "icône de mod B42 absente"
same_asset "$root_dir/assets/branding/poster.png" "$root_dir/poster.png" "poster racine"
same_asset "$root_dir/assets/branding/poster.png" "$root_dir/42/poster.png" "poster B42"
same_asset "$root_dir/assets/branding/poster.png" "$root_dir/workshop/preview.png" "preview Workshop"
same_asset "$root_dir/assets/branding/icon.png" "$root_dir/icon.png" "icône racine"
same_asset "$root_dir/assets/branding/icon.png" "$root_dir/42/icon.png" "icône B42"
for asset_name in memory-status map-memory-marker map-home-marker map-outpost-marker map-vehicle-marker; do
    same_asset "$root_dir/assets/runtime/$asset_name.png" \
        "$root_dir/42/media/ui/SurvivorMemory/$asset_name.png" "$asset_name"
done
if grep -q '^require=.*NeatUI_Framework' "$root_dir/mod.info" "$root_dir/42/mod.info"; then
    fail "NeatUI doit rester optionnel"
fi
if rg -n '^require "neatui_framework/' "$root_dir/42/media/lua/client/SurvivorMemory" \
    --glob '!UICompat.lua' >/dev/null; then
    fail "require NeatUI direct hors UICompat"
fi

python3 "$root_dir/tools/validate_localization.py"

printf 'PASS: invariants SurvivorMemory valides\n'
