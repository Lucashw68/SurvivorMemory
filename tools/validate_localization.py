#!/usr/bin/env python3
"""Validate Survivor Memory's project-specific localization contract."""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
TRANSLATE = ROOT / "42/media/lua/shared/Translate"
REQUIRED_LANGUAGES = ("EN", "CN", "RU", "ES", "PTBR", "FR", "DE")
MOD_KEY = re.compile(r"IGUI_SM_[A-Za-z0-9_]+")
DYNAMIC_PREFIXES = (
    "IGUI_SM_Location_",
    "IGUI_SM_Status_",
    "IGUI_SM_Place_",
    "IGUI_SM_Important_",
)


def fail(message: str) -> None:
    print(f"localization: FAIL ({message})", file=sys.stderr)
    raise SystemExit(1)


def load_language(language: str) -> dict[str, str]:
    path = TRANSLATE / language / "IG_UI.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f"{language}: cannot inspect catalog after generic validation: {exc}")
    if not isinstance(data, dict):
        fail(f"{language}: IG_UI.json must contain an object")
    return data


def lua_sources() -> str:
    return "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "42/media/lua").rglob("*.lua"))
    )


def validate_visible_literals(source: str) -> None:
    visible_call = re.compile(
        r"(?:setTooltip|setTitle|addOption|drawText|drawTextCentre|drawLine)"
        r"\s*\(\s*(['\"])([^'\"]+)\1",
        re.MULTILINE,
    )
    literals = sorted({match.group(2) for match in visible_call.finditer(source)})
    if literals:
        fail("hard-coded player-facing Lua strings: " + ", ".join(repr(x) for x in literals))


def main() -> None:
    actual_languages = tuple(sorted(path.name for path in TRANSLATE.iterdir() if path.is_dir()))
    expected_languages = tuple(sorted(REQUIRED_LANGUAGES))
    if actual_languages != expected_languages:
        missing = sorted(set(expected_languages) - set(actual_languages))
        extra = sorted(set(actual_languages) - set(expected_languages))
        fail(f"language set differs (missing={missing}, extra={extra})")

    translations = {language: load_language(language) for language in REQUIRED_LANGUAGES}
    english = translations["EN"]
    english_keys = set(english)

    source = lua_sources()
    referenced = set(MOD_KEY.findall(source))
    literal_references = {key for key in referenced if not key.endswith("_")}
    missing_from_english = sorted(literal_references - english_keys)
    if missing_from_english:
        fail(f"Lua references missing EN keys: {missing_from_english}")

    obsolete = sorted(
        key for key in english_keys
        if key not in literal_references
        and not any(key.startswith(prefix) and prefix in referenced for prefix in DYNAMIC_PREFIXES)
    )
    if obsolete:
        fail(f"obsolete EN keys not referenced by runtime: {obsolete}")

    validate_visible_literals(source)
    for language in REQUIRED_LANGUAGES:
        print(f"{language}: {len(translations[language])} keys")
    print("localization policy: PASS")


if __name__ == "__main__":
    main()
