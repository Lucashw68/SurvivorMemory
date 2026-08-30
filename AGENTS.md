# AGENTS.md

## Project

This repository is a Project Zomboid Build 42 mod.

Target the locally installed Build 42 version.

## Project-specific rules

Survivor Memory models non-omniscient, character-owned memory. It may remember
only buildings, rooms, and containers the character has actually observed.
Never add magical world scans or remote container scans.

Keep runtime observation event-driven. Avoid polling, repeated building scans,
and knowledge inferred from inaccessible world state.

Memory belongs to the character through player ModData. Do not move it to world
ModData or implicitly share it across characters, accounts, or saves.

NeatUI Framework is an optional UI integration with an existing vanilla
fallback; it is not a declared runtime dependency. Preserve both paths unless a
separate milestone explicitly changes that decision.

Preserve deterministic tests for identities, buildings, rooms, containers,
persistence, visits, and status presentation. The building and save/reload
in-game smoke scenarios are project-specific and remain local.

The World Map overlay is implemented; advanced display filters remain optional
future work. Item Memory is not implemented and must not be introduced through
a global scan or speculative index.

Do not assume that Build 41 APIs, mod structures, recipes, events, classes,
or behaviors are still valid.

When uncertain about a Project Zomboid API or behavior, inspect the local game
files, scripts, classes, or runtime behavior before implementing a workaround.

Do not document assumptions as verified facts.

## Development tooling

This project uses PzModTools for generic development tooling.

Do not reimplement generic:

- build logic;
- packaging;
- local mod installation;
- generic validation;
- Lua syntax validation;
- translation validation;
- log collection and filtering;
- generic Project Zomboid launch helpers;
- generic smoke-test infrastructure.

Before adding development tooling, check whether PzModTools already provides it.

The project Makefile includes PzModTools and declares the exact version against
which this mod has been validated.

Standard commands are provided through PzModTools:

    make test
    make validate
    make build
    make package
    make install
    make install-dry-run
    make dev
    make logs
    make logs-errors
    make smoke
    make info
    make version

Use these commands rather than creating alternative workflows.

If a required development capability is missing from PzModTools, do not silently
create a second generic implementation in this repository.

First determine whether the capability:

1. is generic and belongs in PzModTools; or
2. is specific to this mod and belongs locally.

Mod-specific tests, validation rules, smoke scenarios, and development helpers
may remain in this repository when they are genuinely specific to the mod.

## Repository responsibilities

PzModTools owns generic development infrastructure.

This repository owns:

- gameplay and mod behavior;
- mod-specific runtime code;
- mod-specific assets;
- mod-specific dependencies;
- mod-specific tests;
- mod-specific smoke scenarios;
- mod-specific validation;
- mod-specific documentation.

PzModTools is a development dependency only.

Never include PzModTools files in the runtime mod package.

## Build 42 structure

Respect the Project Zomboid Build 42 mod structure.

Keep client, server, and shared responsibilities separated appropriately.

Do not move code between client, server, and shared contexts merely to work
around an issue without understanding the runtime and multiplayer implications.

Keep runtime files separate from development tooling, tests, documentation,
and generated artifacts.

## Dependencies

Do not introduce dependencies unless they are required by the mod.

Dependencies must be explicit and documented.

Do not assume that another mod, framework, library, or Workshop item is
available unless this project explicitly declares it as a dependency.

Avoid adding dependencies for functionality that can be implemented simply and
reliably without them.

## Tests

Separate gameplay/business logic from Project Zomboid runtime glue where
practical so that deterministic tests can cover the core behavior.

Every bug fix should receive a regression test when reasonably possible.

Before considering work complete, run at least:

    make test
    make validate
    make build

For changes affecting actual Project Zomboid runtime behavior, run the
appropriate mod-specific smoke test when one exists.

Never claim an in-game behavior was validated unless an actual in-game test
was performed.

Clearly distinguish:

- deterministic validation;
- static validation;
- simulated tests;
- actual in-game validation.

## Reverse engineering

Prefer verified Build 42 behavior over assumptions or outdated documentation.

When necessary, inspect:

- vanilla Lua;
- scripts;
- Java classes;
- game data;
- logs;
- runtime behavior.

Record important reverse-engineering findings when they affect implementation
decisions or future maintenance.

Keep verified facts separate from hypotheses.

## Performance

Project Zomboid mods may run for long sessions and on long-lived saves.

Avoid unnecessary:

- per-frame work;
- global world scans;
- repeated container scans;
- allocations in hot paths;
- serialization;
- network traffic.

Prefer event-driven behavior when appropriate.

Do not optimize speculatively when there is no meaningful runtime concern.

## Multiplayer

Do not assume single-player behavior is automatically correct in multiplayer.

For code involving persistent state, world state, player state, or gameplay
authority, explicitly consider:

- client ownership;
- server ownership;
- synchronization;
- reconnect behavior;
- multiple players;
- dedicated servers.

Do not introduce networking when the feature can correctly remain local.

## Persistence

Persistent data must use an explicit, maintainable structure.

Version persistent formats when future changes could otherwise make existing
saves incompatible.

Do not silently discard unknown or older data without understanding the
migration consequences.

Avoid storing data that can be cheaply and reliably reconstructed.

## Safety

Be careful with development scripts performing destructive operations such as:

- rm -rf;
- rsync --delete;
- installation;
- cleanup;
- temporary profile removal.

Use the safeguards provided by PzModTools.

Do not bypass them with ad-hoc destructive commands.

Never perform destructive operations on paths that have not been explicitly
validated.

## Scope

Prefer the smallest implementation that correctly solves the current
requirement.

Do not introduce frameworks, abstraction layers, compatibility systems,
configuration systems, or tooling for hypothetical future requirements.

Generalize only when there is a demonstrated need.

Do not add Build 41 compatibility unless explicitly requested.

Do not add legacy compatibility unless explicitly requested.

## Generated artifacts

Do not commit generated or temporary artifacts unless the project explicitly
requires them.

Keep build outputs, temporary profiles, logs, screenshots, generated test
results, and local environment files out of the runtime package.

Follow the repository's `.gitignore` and PzModTools packaging rules.

## Documentation

Keep documentation focused on information useful for development and
maintenance.

Document:

- important architecture decisions;
- verified Build 42 behavior;
- non-obvious constraints;
- persistence formats;
- important test procedures;
- known limitations.

Do not preserve temporary investigation reports indefinitely when their useful
conclusions can be incorporated into permanent documentation.

If something has not been verified in game, state that explicitly.

