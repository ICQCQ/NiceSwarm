#!/usr/bin/env bash
# Parallel playstyle-sim runner. Runs many NICESWARM_SIM games at once — each is its own
# headless godot process, so they're CPU-parallel. Faithful even under contention because
# the sim sets max_physics_steps_per_frame uncapped: a starved run just stretches in
# wall-clock, it never under-simulates.
#
# Jobs are read from stdin, one per line: "<style> <players> <seed>".
# Usage:  <generate jobs> | bash tests/sim_par.sh [pool] [ff]
#   pool  concurrent runs (default 8; ~60% of nproc is a good target)
#   ff    engine time-scale per run (default 4; keep low)
# Prints each run's [sim] line as it finishes.
set -u
GODOT="${GODOT:-C:/Users/zalzer/scoop/apps/godot/current/godot.console.exe}"
POOL="${1:-8}"
FF="${2:-4}"
export GODOT FF

_run() {
  set -- $1   # split "style players seed"
  local line
  line=$(NICESWARM_SIM="style=$1,players=$2,seed=$3,ff=$FF" timeout 700 \
    "$GODOT" --headless --path . --quit-after 500000 2>/dev/null | grep '^\[sim\]')
  [ -n "$line" ] && echo "$line"
}
export -f _run

xargs -P "$POOL" -d '\n' -I{} bash -c '_run "{}"'
