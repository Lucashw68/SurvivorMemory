PZ_MOD_TOOLS ?= ../PzModTools
PZ_MOD_TOOLS_VERSION := 0.3.0
LOG_FILTER := \[SurvivorMemory\]
MOD_VALIDATE_COMMAND := ./tools/validate.sh
MOD_SMOKE_COMMAND := sh tools/run_building_smoke.sh

include $(PZ_MOD_TOOLS)/make/pz-mod.mk
