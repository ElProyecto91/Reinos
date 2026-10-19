#!/bin/bash
# Reconstruye el arte de las civilizaciones del juego: hornea cada una (tools/iso/civ_preview.sh), la funde en la carpeta de sprites
# de trabajo, regenera los paquetes de art/iso (iso_atlas.py), los datos de humo (civ_meta.gd) e importa los recursos.
# Uso: tools/iso/civ_build.sh [civ1,civ2,...]   (sin argumentos: todas las de IsoCivs.available())
# Variables: SPR=/tmp/iso_all (carpeta con todos los sprites ya horneados: unidades, terreno… y las civs; se crea si falta con las civs)
# Para añadir una civilización nueva: escribir tools/iso/civ/<id>.gd (ver _plantilla.gd), añadirla a IsoCivs.DIR y ejecutar esto con su id.
set -e
cd "$(dirname "$0")/../.."
[ -z "$GODOT" ] && source /tmp/godot_env.sh 2>/dev/null
: "${GODOT:?define GODOT con la ruta del ejecutable de Godot 4.4}"
SPR=${SPR:-/tmp/iso_all}
mkdir -p "$SPR"
if [ -n "$1" ]; then
  CIVS=${1//,/ }
else
  CIVS=$($GODOT --headless --path . --script res://tools/iso/civ_list.gd 2>/dev/null | grep '^civs:' | sed 's/^civs: //')
fi
for civ in $CIVS; do
  echo "== $civ"
  tools/iso/civ_preview.sh "$civ" >/tmp/civ_build_$civ.log 2>&1 || { cat /tmp/civ_build_$civ.log; exit 1; }
  python3 - "$SPR" "/tmp/civ_spr/$civ" "$civ" <<'EOF'
import json, os, shutil, sys
dst, src, civ = sys.argv[1:4]
A = json.load(open(os.path.join(dst, "anchors.json"))) if os.path.exists(os.path.join(dst, "anchors.json")) else {}
for k in [k for k in A if k.startswith(civ + "__")]:
    del A[k]
for f in os.listdir(src):
    if f.endswith(".png"):
        shutil.copy2(os.path.join(src, f), os.path.join(dst, f))
A.update(json.load(open(os.path.join(src, "anchors.json"))))
json.dump(A, open(os.path.join(dst, "anchors.json"), "w"))
print("  ", len([k for k in A if k.startswith(civ + "__")]), "sprites en", dst)
EOF
done
python3 tools/iso/iso_atlas.py "$SPR" art/iso | tail -4
$GODOT --headless --path . --script res://tools/iso/civ_meta.gd 2>&1 | grep '^meta'
xvfb-run -a $GODOT --headless --path . --import >/tmp/civ_import.log 2>&1 || true   # registra los PNG nuevos
git checkout -- project.godot 2>/dev/null || true
