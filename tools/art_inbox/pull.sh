#!/usr/bin/env bash
# Pide al flujo «Art inbox» que descargue imágenes por URL, espera, y las extrae en un directorio local (nunca dentro del proyecto).
# Uso: tools/art_inbox/pull.sh DESTINO nombre=https://... [nombre2=https://...]
set -euo pipefail
dest="${1:?destino}"; shift
[ "$#" -ge 1 ] || { echo "faltan elementos nombre=URL"; exit 2; }
repo="ElProyecto91/Reinos"
urls="$*"
before=$(gh api "repos/$repo/actions/workflows/art-inbox.yml/runs?per_page=1" --jq '.workflow_runs[0].id // 0')
body=$(python3 -c 'import json,sys; print(json.dumps({"ref":"main","inputs":{"urls":sys.argv[1]}}))' "$urls")
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -H 'Accept: application/vnd.github+json' -d "$body" "https://api.github.com/repos/$repo/actions/workflows/art-inbox.yml/dispatches")
[ "$code" = 204 ] || { echo "el disparo falló (HTTP $code)"; exit 1; }
for _ in $(seq 1 60); do
  sleep 5
  row=$(gh api "repos/$repo/actions/workflows/art-inbox.yml/runs?per_page=1" --jq '.workflow_runs[0]|[.id,.status,.conclusion // "-"]|@tsv')
  id=${row%%$'\t'*}
  [ "$id" != "$before" ] || continue
  case "$row" in *completed*success*) break;; *completed*) echo "el flujo terminó mal: $row"; exit 1;; esac
done
git fetch -q origin art-inbox 2>&1 | grep -v moved || true
mkdir -p "$dest"
git archive origin/art-inbox art/inbox | tar -x -C "$dest" --strip-components=2
ls -la "$dest"
