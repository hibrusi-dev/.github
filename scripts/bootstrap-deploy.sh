#!/usr/bin/env bash
# =====================================================================
# Bootstrap CI/CD — crea o ACTUALIZA el caller de despliegue en todos
# los repos de la organización. Idempotente.
#   - Si el repo no tiene deploy.yml -> lo crea.
#   - Si tiene uno puesto por este bootstrap -> lo actualiza.
#   - Si tiene un deploy.yml PROPIO (sin nuestra marca) -> lo respeta.
#
#   Uso:    ./scripts/bootstrap-deploy.sh
#   Excluir repos:  ORG_EXCLUDES=".github otro" ./scripts/bootstrap-deploy.sh
# Requiere: gh CLI autenticado con scope 'repo' + 'workflow'.
# =====================================================================
set -euo pipefail

ORG="hibrusi-dev"
WF_PATH=".github/workflows/deploy.yml"
MARKER="bootstrap CI/CD de"          # marca para reconocer callers nuestros
EXCLUDES="${ORG_EXCLUDES:-.github}"

read -r -d '' CALLER <<'YAML' || true
# Añadido por el bootstrap CI/CD de hibrusi-dev.
# La lógica vive en hibrusi-dev/.github (reusable workflow central).
name: Deploy

on:
  push:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      target:
        description: "¿A qué VPS desplegar?"
        type: choice
        options: [ vps1, vps2 ]
        default: vps1

jobs:
  deploy:
    uses: hibrusi-dev/.github/.github/workflows/deploy-reusable.yml@main
    with:
      target: ${{ inputs.target }}
    secrets: inherit
YAML

CONTENT_B64="$(printf '%s' "$CALLER" | base64 | tr -d '\n')"

echo "==> Repos de $ORG (excluyo: $EXCLUDES)"
mapfile -t REPOS < <(gh repo list "$ORG" --limit 200 \
  --json name,defaultBranchRef \
  --jq '.[] | "\(.name)\t\(.defaultBranchRef.name // "main")"')

created=0; updated=0; skipped=0
for line in "${REPOS[@]}"; do
  name="${line%%$'\t'*}"
  branch="${line##*$'\t'}"

  for ex in $EXCLUDES; do
    if [[ "$name" == "$ex" ]]; then
      echo "·  $name (excluido)"; skipped=$((skipped+1)); continue 2
    fi
  done

  sha="$(gh api "repos/$ORG/$name/contents/$WF_PATH?ref=$branch" --jq '.sha' 2>/dev/null || true)"

  if [[ -n "$sha" ]]; then
    cur="$(gh api "repos/$ORG/$name/contents/$WF_PATH?ref=$branch" --jq '.content' 2>/dev/null | tr -d '\n' | base64 -d 2>/dev/null || true)"
    if ! printf '%s' "$cur" | grep -q "$MARKER"; then
      echo "=  $name (deploy.yml propio, respetado)"; skipped=$((skipped+1)); continue
    fi
    if [[ "$(printf '%s' "$cur" | base64 | tr -d '\n')" == "$CONTENT_B64" ]]; then
      echo "=  $name (ya actualizado)"; skipped=$((skipped+1)); continue
    fi
    gh api -X PUT "repos/$ORG/$name/contents/$WF_PATH" \
      -f message="ci: update deploy caller (multi-VPS)" \
      -f content="$CONTENT_B64" -f sha="$sha" -f branch="$branch" >/dev/null \
      && { echo "~  $name (caller actualizado)"; updated=$((updated+1)); }
  else
    gh api -X PUT "repos/$ORG/$name/contents/$WF_PATH" \
      -f message="ci: add deploy caller workflow (hibrusi-dev CI/CD)" \
      -f content="$CONTENT_B64" -f branch="$branch" >/dev/null \
      && { echo "+  $name (caller añadido)"; created=$((created+1)); }
  fi
done

echo "==> Hecho. Nuevos: $created · Actualizados: $updated · Saltados: $skipped"
