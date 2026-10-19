#!/bin/bash
# Hornea y revisa la arquitectura de una civilización sin tocar el atlas del juego.
# Uso: tools/iso/civ_preview.sh <civ> [nombres separados por comas] [equipo]
#   sin nombres: todo lo de la civilización; con nombres: sólo esos sprites (p. ej. castellanos__casa,castellanos__cuartel)
# Escribe /tmp/civ_raw/<civ>, /tmp/civ_spr/<civ> y /tmp/civ_sheet_<civ>.png
CIV=$1
NAMES=$2
cd "$(dirname "$0")/../.."
source /tmp/godot_env.sh
RAW=/tmp/civ_raw/$CIV
SPR=/tmp/civ_spr/$CIV
mkdir -p $RAW $SPR
ARGS="out=$RAW only=civ_$CIV*"
[ -n "$NAMES" ] && ARGS="$ARGS names=$NAMES"
timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . res://tools/iso/iso_bake.tscn --rendering-driver opengl3 --resolution 800x600 -- $ARGS > /tmp/civ_bake_$CIV.log 2>&1
grep -v "ALSA\|CANT_OPEN" /tmp/civ_bake_$CIV.log | grep -i "info\|error\|script\|parse" | head -20
python3 tools/iso/iso_post.py $RAW $SPR | tail -3
python3 tools/iso/civ_sheet.py $SPR $CIV /tmp/civ_sheet_$CIV.png equipo=${3:-azul}
