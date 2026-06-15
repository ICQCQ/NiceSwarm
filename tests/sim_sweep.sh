#!/usr/bin/env bash
# Headless playstyle-sim sweep -> balance data. Drives the NICESWARM_SIM autopilot
# (kiting-bot players, playstyle-priority auto-picks) across playstyles, seeds and
# player counts, then prints raw [sim] lines followed by per-group averages.
#
# Usage:  bash tests/sim_sweep.sh [ff] ["seeds"]
#   ff    engine time-scale (default 5; keep low — high ff time-dilates the headless host)
#   seeds space-separated seed list (default "1 2 3")
set -u
GODOT="${GODOT:-C:/Users/zalzer/scoop/apps/godot/current/godot.console.exe}"
FF="${1:-5}"
SEEDS="${2:-1 2 3}"
STYLES="railgun pulsar supernova glacier prism toxicpyre warhead singular cluster storm frostbite greedy"
OUT="sim_results.tsv"
: > "$OUT"

run() { # style players seed
  local line
  line=$(NICESWARM_SIM="style=$1,players=$2,seed=$3,ff=$FF" timeout 300 \
    "$GODOT" --headless --path . --quit-after 80000 2>/dev/null | grep '^\[sim\]')
  if [ -z "$line" ]; then echo "FAILED style=$1 players=$2 seed=$3"; return; fi
  echo "$line"
  echo "$line" | sed -E 's/^\[sim\] //; s/[a-z_]+=//g' \
    | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9}' >> "$OUT"
}

echo "### style sweep (1 player, ff=$FF) ###"
for s in $STYLES; do for seed in $SEEDS; do run "$s" 1 "$seed"; done; done

echo "### player-count sweep (railgun + greedy, ff=$FF) ###"
for s in railgun greedy; do for p in 2 3 4; do for seed in $SEEDS; do run "$s" "$p" "$seed"; done; done; done

echo
echo "=== per-style averages (1 player), sorted by difficulty reached ==="
awk -F'\t' '$2==1{n[$1]++;t[$1]+=$5;d[$1]+=$6;l[$1]+=$7;k[$1]+=$8;tk[$1]+=$9;if($4=="WIN")w[$1]++}
END{printf "%-11s %4s %7s %6s %6s %6s %5s %5s\n","style","run","time","diff","level","kills","ttk","wins";
for(s in n)printf "%-11s %4d %7.1f %6.2f %6.1f %6.1f %5.2f %5d\n",s,n[s],t[s]/n[s],d[s]/n[s],l[s]/n[s],k[s]/n[s],tk[s]/n[s],w[s]+0}' "$OUT" | (read h; echo "$h"; sort -k4 -rn)

echo
echo "=== player-count vs difficulty/survival (avg over seeds) ==="
awk -F'\t' '{key=$1"/"$2;n[key]++;t[key]+=$5;d[key]+=$6;k[key]+=$8}
END{printf "%-14s %4s %7s %6s %6s\n","style/players","run","time","diff","kills";
for(key in n)printf "%-14s %4d %7.1f %6.2f %6.1f\n",key,n[key],t[key]/n[key],d[key]/n[key],k[key]/n[key]}' "$OUT" | (read h; echo "$h"; sort)
echo "(raw rows in $OUT)"
