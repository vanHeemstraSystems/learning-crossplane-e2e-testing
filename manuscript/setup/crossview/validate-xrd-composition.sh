#!/usr/bin/env bash

# Validate XRD <-> Composition matching (apiVersion + kind).
#
# Usage:
#   ./validate-xrd-composition.sh <xrd-name> [composition-name]
#
# Examples:
#   ./validate-xrd-composition.sh xpostgresqldatabases.database.example.io
#   ./validate-xrd-composition.sh xpostgresqldatabases.database.example.io xpostgresqldatabases.database.example.io

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

die() {
  echo "${RED}ERROR:${NC} $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

need kubectl
need jq

usage() {
  cat <<'EOF'
Usage:
  ./validate-xrd-composition.sh <xrd-name> [composition-name]

If composition-name is omitted, the script lists compositions that match this XRD.
EOF
}

XRD_NAME="${1:-}"
COMPOSITION_NAME="${2:-}"

if [[ -z "$XRD_NAME" ]]; then
  usage
  echo
  echo "Available XRDs:"
  kubectl get xrd -o name 2>/dev/null | sed 's|^.*\/||' | sed 's/^/  - /' || true
  exit 1
fi

echo "${BLUE}=== Crossplane XRD-Composition Validation ===${NC}"
echo

if ! kubectl get xrd "$XRD_NAME" >/dev/null 2>&1; then
  die "XRD not found: $XRD_NAME"
fi

XRD_JSON="$(kubectl get xrd "$XRD_NAME" -o json)"
XRD_GROUP="$(jq -r '.spec.group' <<<"$XRD_JSON")"
XRD_KIND="$(jq -r '.spec.names.kind' <<<"$XRD_JSON")"
XRD_VERSION="$(
  jq -r '
    .spec.versions
    | (map(select(.referenceable==true and .served==true)) | .[0].name)
      // (map(select(.served==true)) | .[0].name)
      // .[0].name
  ' <<<"$XRD_JSON"
)"
XRD_APIVERSION="${XRD_GROUP}/${XRD_VERSION}"
XRD_ESTABLISHED="$(jq -r '.status.conditions[]? | select(.type=="Established") | .status' <<<"$XRD_JSON" | head -n1)"

echo "XRD:"
echo "  Name:        ${XRD_NAME}"
echo "  API Version: ${XRD_APIVERSION}"
echo "  Kind:        ${XRD_KIND}"
if [[ "${XRD_ESTABLISHED:-}" == "True" ]]; then
  echo "  Status:      ${GREEN}Established${NC}"
else
  echo "  Status:      ${YELLOW}${XRD_ESTABLISHED:-Unknown}${NC}"
fi

echo

get_comp_ref() {
  local name="$1"
  kubectl get composition "$name" -o json \
    | jq -r '.spec.compositeTypeRef | "\(.apiVersion)|\(.kind)"'
}

validate_pair() {
  local comp="$1"
  local ref api kind
  ref="$(get_comp_ref "$comp")"
  api="${ref%%|*}"
  kind="${ref##*|}"

  echo "Composition: ${comp}"
  echo "  API Version: ${api}"
  echo "  Kind:        ${kind}"

  local ok=true
  if [[ "$api" == "$XRD_APIVERSION" ]]; then
    echo "  API Match:   ${GREEN}✓${NC}"
  else
    echo "  API Match:   ${RED}✗${NC} (expected ${XRD_APIVERSION})"
    ok=false
  fi

  if [[ "$kind" == "$XRD_KIND" ]]; then
    echo "  Kind Match:  ${GREEN}✓${NC}"
  else
    echo "  Kind Match:  ${RED}✗${NC} (expected ${XRD_KIND})"
    ok=false
  fi

  $ok
}

if [[ -n "$COMPOSITION_NAME" ]]; then
  if ! kubectl get composition "$COMPOSITION_NAME" >/dev/null 2>&1; then
    die "Composition not found: $COMPOSITION_NAME"
  fi

if validate_pair "$COMPOSITION_NAME"; then
    echo
    echo "${GREEN}=== VALIDATION PASSED ===${NC}"
    exit 0
  fi

  echo
  echo "${RED}=== VALIDATION FAILED ===${NC}"
  exit 1
fi

echo "Finding Compositions that match this XRD (compositeTypeRef)..."
COMPS_JSON="$(kubectl get composition -o json)"
MATCH_EXACT="$(
  jq -r --arg api "$XRD_APIVERSION" --arg kind "$XRD_KIND" '
    .items[]
    | select(.spec.compositeTypeRef.apiVersion == $api and .spec.compositeTypeRef.kind == $kind)
    | .metadata.name
  ' <<<"$COMPS_JSON"
)"
MATCH_KIND_ONLY="$(
  jq -r --arg api "$XRD_APIVERSION" --arg kind "$XRD_KIND" '
    .items[]
    | select(.spec.compositeTypeRef.kind == $kind and .spec.compositeTypeRef.apiVersion != $api)
    | .metadata.name
  ' <<<"$COMPS_JSON"
)"

if [[ -z "${MATCH_EXACT}" && -z "${MATCH_KIND_ONLY}" ]]; then
  echo "${YELLOW}No Compositions found for kind ${XRD_KIND}.${NC}"
  echo
  echo "All available Compositions:"
  kubectl get composition -o name 2>/dev/null | sed 's|^.*\/||' | sed 's/^/  - /' || true
  exit 0
fi

if [[ -n "${MATCH_EXACT}" ]]; then
  echo
  echo "${GREEN}Exact matches (apiVersion + kind):${NC}"
  while IFS= read -r comp; do
    [[ -z "$comp" ]] && continue
    echo "  - $comp"
  done <<<"$MATCH_EXACT"
fi

if [[ -n "${MATCH_KIND_ONLY}" ]]; then
  echo
  echo "${YELLOW}Kind matches but apiVersion differs:${NC}"
  while IFS= read -r comp; do
    [[ -z "$comp" ]] && continue
    ref="$(get_comp_ref "$comp")"
    echo "  - $comp (has ${ref%%|*})"
  done <<<"$MATCH_KIND_ONLY"
fi

echo
echo "Tip: to validate a specific composition:"
echo "  ./validate-xrd-composition.sh ${XRD_NAME} <composition-name>"
