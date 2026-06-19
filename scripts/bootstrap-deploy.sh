#!/usr/bin/env bash
# =====================================================================
# Bootstrap CI/CD — añade el caller de despliegue a TODOS los repos de
# la organización que aún no lo tengan. Idempotente: salta los que ya
# lo tienen. La lógica real vive en el reusable workflow central.
#
#   Uso:    ./scripts/bootstrap-deploy.sh
#   Excluir repos:  ORG_EXCLUDES=".github otroRepo" ./scripts/bootstrap-deploy.sh
#
# Requiere: gh CLI autenticado con scope 'repo' + 'workflow'.
# =====================================================================
set -euo pipefail

ORG="hibrusi-dev"
WF_PATH=".github/workflows/deploy.yml"
# Repos a NO tocar (el propio .github no se despliega).
EXCLUDES="${ORG_EXCLUDES:-.github}"

read -r -d '' CALLER <<'YAML' || true
# Añadido por el bootstrap CI/CD de hibrusi-dev.
# La lógica vive en hibrusi-dev/.github (reusable workflow central).
name: Deploy

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    uses: hibrusi-dev/.github/.github/workflows/deploy-reusable.yml@main
    secrets: inherit
YAML

CONTENT_B64="$(printf '%s' "$CALLER" | base64 | tr -d '\n')"

echo "==> Repos de $ORG (excluyo: $EXCLUDES)"
mapfile -t REPOS < <(gh repo list "$ORG" --limit 200 \
  --json name,defaultBranchRef \
  --jq '.[] | "\(.name)\t\(.defaultBranchRef.name // "main")"')

added=0; skipped=0
for line in "${REPOS[@]}"; do
  name="${line%%$'\t'*}"
  branch="${line##*$'\t'}"

  for ex in $EXCLUDES; do
    if [[ "$name" == "$ex" ]]; then
      echo "·  $name (excluido)"; skipped=$((skipped+1)); continue 2
    fi
  done

  if gh api "repos/$ORG/$name/contents/$WF_PATH?ref=$branch" >/dev/null 2>&1; then
    echo "=  $name (ya tiene deploy.yml)"; skipped=$((skipped+1)); continue
  fi

  gh api -X PUT "repos/$ORG/$name/contents/$WF_PATH" \
    -f message="ci: add deploy caller workflow (hibrusi-dev CI/CD)" \
    -f content="$CONTENT_B64" \
    -f branch="$branch" >/dev/null \
    && { echo "+  $name (caller añadido a $branch)"; added=$((added+1)); }
done

echo "==> Hecho. Añadidos: $added · Saltados: $skipped"
