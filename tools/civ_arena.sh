#!/bin/bash
# Torneo de civilizaciones: IA contra IA, todas las parejas en los dos asientos y varios mapas.
# Uso (desde la raíz del proyecto, con $GODOT apuntando al ejecutable de Godot 4.4.1):
#   tools/civ_arena.sh /tmp/arena.txt 3 8 13            # todas las parejas, mapas de semilla 3, 8 y 13 (~30 min con 2 núcleos)
#   WITHNONE=1 tools/civ_arena.sh /tmp/a.txt 3 8        # además cada civilización contra «sin civilización»
#   ONLY="mongoles|bizantinos" tools/civ_arena.sh ...   # solo las parejas que contienen esos nombres
# Después:  python3 tools/civ_arena_report.py /tmp/arena.txt
OUT=$1; shift
SEEDS="$@"
: > "$OUT"
CIVS="castellanos francos ingleses teutones vikingos bizantinos sarracenos mongoles"
JOBS=$(mktemp)
for s in $SEEDS; do
  for a in $CIVS; do
    if [ "$WITHNONE" = 1 ]; then echo "$s $a none" >> $JOBS; echo "$s none $a" >> $JOBS; fi
    for b in $CIVS; do
      if [[ "$a" < "$b" ]]; then echo "$s $a $b" >> $JOBS; echo "$s $b $a" >> $JOBS; fi
    done
  done
done
if [ -n "$ONLY" ]; then grep -E "$ONLY" $JOBS > $JOBS.f && mv $JOBS.f $JOBS; fi
runone() {
  s=$1; a=$2; b=$3; ca=$a; cb=$b
  [ "$a" = none ] && ca=""
  [ "$b" = none ] && cb=""
  timeout 900 $GODOT --headless --path . --script res://tools/ai_match.gd -- seed=$s p0=new p1=new d0=1 d1=1 min=40 c0=$ca c1=$cb 2>&1 | grep RESULT >> $OUT
}
export -f runone
export GODOT OUT
cat $JOBS | xargs -P 2 -L 1 bash -c 'runone $0 $1 $2'
echo ALLDONE >> $OUT
