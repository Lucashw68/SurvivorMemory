# Localization

English is Survivor Memory’s canonical source language. Runtime strings use
Build 42’s native `getText` mechanism and the `IGUI_SM_` namespace. The
supported language directories are:

- `EN` — English;
- `CN` — Simplified Chinese;
- `RU` — Russian;
- `ES` — Spanish;
- `PTBR` — Brazilian Portuguese;
- `FR` — French;
- `DE` — German.

Project Zomboid selects the matching catalogue from its configured language;
Survivor Memory has no separate language option. Dynamic values use B42 `%1`,
`%2`, etc. placeholders inside complete translated strings. Numeric wording is
kept neutral where a language would otherwise require unsupported plural rules.

`make validate` first uses PzModTools 0.4.1 for the generic contract: JSON
syntax, UTF-8 decoding, duplicate detection, non-empty values, file/key parity
and numbered-placeholder parity. The project-specific localization check only
enforces Survivor Memory’s exact seven-language policy, `IGUI_SM_*` runtime-key
coverage, absence of obsolete mod keys and obvious hard-coded strings passed
directly to this mod’s player-facing Lua UI methods.

## Workshop publishing

The current PzModTools 0.4.1 / Project Zomboid local Workshop workflow accepts
one repeated `description=` field set. Project Zomboid’s uploader uses the
default Workshop language and its local screen exposes no description-language
selector or `SetItemUpdateLanguage` path. Native per-language descriptions are
therefore not supported cleanly by the current workflow.

The existing Workshop item remains single and its canonical public description
remains English. No parallel Workshop items or speculative publishing scripts
are used. Runtime localization is independent from Workshop metadata.

Workshop screenshots must also be captured with Project Zomboid set to
English. The project smoke harness enforces English only in its isolated test
profile, leaving the normal player profile unchanged.

The 2026-09-01 in-game smoke passed with both NeatUI and the vanilla fallback.
It produced an English World Map capture suitable for review. Its English panel
capture still showed the smoke console, so that file was archived under
`research/screenshots/localization-preflight/` rather than presented as a
Workshop-ready screenshot.
