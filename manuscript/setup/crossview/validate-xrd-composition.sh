#!/bin/bash

# XRD-Composition Validation Script

# This script validates that a Composition correctly references an XRD

set -e

# Colors for output

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
BLUE=’\033[0;34m’
NC=’\033[0m’ # No Color

echo “=== Crossplane XRD-Composition Validation ===”
echo “”

# Function to check if a resource exists

check_resource() {
local resource_type=$1
local resource_name=$2

```
if kubectl get "$resource_type" "$resource_name" &> /dev/null; then
    return 0
else
    return 1
fi
```

}

# Function to extract compositeTypeRef from Composition

get_composite_type_ref() {
local composition_name=$1
kubectl get composition “$composition_name” -o json | jq -r ‘.spec.compositeTypeRef | “(.apiVersion)|(.kind)”’
}

# Function to extract XRD details

get_xrd_details() {
local xrd_name=$1
local group=$(kubectl get xrd “$xrd_name” -o jsonpath=’{.spec.group}’)
local version=$(kubectl get xrd “$xrd_name” -o jsonpath=’{.spec.versions[?(@.referenceable==true)].name}’ | head -n1)
local kind=$(kubectl get xrd “$xrd_name” -o jsonpath=’{.spec.names.kind}’)
echo “${group}/${version}|${kind}”
}

# Check if XRD name is provided

if [ -z “$1” ]; then
echo -e “${YELLOW}Usage: $0 <xrd-name> [composition-name]${NC}”
echo “”
echo “Available XRDs:”
kubectl get xrd –no-headers | awk ‘{print “  - “ $1}’
echo “”
exit 1
fi

XRD_NAME=$1
COMPOSITION_NAME=$2

# Check if XRD exists

echo “Checking XRD: $XRD_NAME”
if ! check_resource “xrd” “$XRD_NAME”; then
echo -e “${RED}✗ XRD ‘$XRD_NAME’ not found${NC}”
exit 1
fi
echo -e “${GREEN}✓ XRD found${NC}”

# Get XRD details

XRD_DETAILS=$(get_xrd_details “$XRD_NAME”)
XRD_API_VERSION=$(echo “$XRD_DETAILS” | cut -d’|’ -f1)
XRD_KIND=$(echo “$XRD_DETAILS” | cut -d’|’ -f2)

echo “”
echo “XRD Details:”
echo “  Name:        $XRD_NAME”
echo “  API Version: $XRD_API_VERSION”
echo “  Kind:        $XRD_KIND”

# Check XRD status

XRD_ESTABLISHED=$(kubectl get xrd “$XRD_NAME” -o jsonpath=’{.status.conditions[?(@.type==“Established”)].status}’)
if [ “$XRD_ESTABLISHED” == “True” ]; then
echo -e “  Status:      ${GREEN}Established${NC}”
else
echo -e “  Status:      ${YELLOW}Not Established${NC}”
fi

echo “”

# If composition name not provided, find matching compositions

if [ -z “$COMPOSITION_NAME” ]; then
echo “Finding Compositions that reference this XRD…”
MATCHING_COMPOSITIONS=$(kubectl get composition -o json | jq -r –arg kind “$XRD_KIND” ‘.items[] | select(.spec.compositeTypeRef.kind == $kind) | .metadata.name’)

```
if [ -z "$MATCHING_COMPOSITIONS" ]; then
    echo -e "${YELLOW}No Compositions found that reference this XRD${NC}"
    echo ""
    echo "All available Compositions:"
    kubectl get composition --no-headers | awk '{print "  - " $1}'
    exit 0
fi

echo "Found matching Compositions:"
echo "$MATCHING_COMPOSITIONS" | while read -r comp; do
    echo "  - $comp"
done
echo ""

# Validate each matching composition
echo "Validating each Composition..."
VALIDATION_PASSED=true

echo "$MATCHING_COMPOSITIONS" | while read -r comp; do
    echo ""
    echo "Composition: $comp"
    
    COMP_REF=$(get_composite_type_ref "$comp")
    COMP_API_VERSION=$(echo "$COMP_REF" | cut -d'|' -f1)
    COMP_KIND=$(echo "$COMP_REF" | cut -d'|' -f2)
    
    echo "  API Version: $COMP_API_VERSION"
    echo "  Kind:        $COMP_KIND"
    
    # Check if API versions match
    if [ "$COMP_API_VERSION" == "$XRD_API_VERSION" ]; then
        echo -e "  API Match:   ${GREEN}✓ Matches${NC}"
    else
        echo -e "  API Match:   ${RED}✗ Mismatch${NC}"
        echo "    Expected: $XRD_API_VERSION"
        echo "    Got:      $COMP_API_VERSION"
        VALIDATION_PASSED=false
    fi
    
    # Check if kinds match
    if [ "$COMP_KIND" == "$XRD_KIND" ]; then
        echo -e "  Kind Match:  ${GREEN}✓ Matches${NC}"
    else
        echo -e "  Kind Match:  ${RED}✗ Mismatch${NC}"
        echo "    Expected: $XRD_KIND"
        echo "    Got:      $COMP_KIND"
        VALIDATION_PASSED=false
    fi
done
```

else
# Validate specific composition
echo “Checking Composition: $COMPOSITION_NAME”
if ! check_resource “composition” “$COMPOSITION_NAME”; then
echo -e “${RED}✗ Composition ‘$COMPOSITION_NAME’ not found${NC}”
exit 1
fi
echo -e “${GREEN}✓ Composition found${NC}”

```
echo ""
COMP_REF=$(get_composite_type_ref "$COMPOSITION_NAME")
COMP_API_VERSION=$(echo "$COMP_REF" | cut -d'|' -f1)
COMP_KIND=$(echo "$COMP_REF" | cut -d'|' -f2)

echo "Composition Details:"
echo "  Name:        $COMPOSITION_NAME"
echo "  API Version: $COMP_API_VERSION"
echo "  Kind:        $COMP_KIND"

echo ""
echo "Validation Results:"

VALIDATION_PASSED=true

# Check if API versions match
if [ "$COMP_API_VERSION" == "$XRD_API_VERSION" ]; then
    echo -e "  ${GREEN}✓ API Version matches${NC}"
else
    echo -e "  ${RED}✗ API Version mismatch${NC}"
    echo "    XRD has:         $XRD_API_VERSION"
    echo "    Composition has: $COMP_API_VERSION"
    VALIDATION_PASSED=false
fi

# Check if kinds match
if [ "$COMP_KIND" == "$XRD_KIND" ]; then
    echo -e "  ${GREEN}✓ Kind matches${NC}"
else
    echo -e "  ${RED}✗ Kind mismatch${NC}"
    echo "    XRD has:         $XRD_KIND"
    echo "    Composition has: $COMP_KIND"
    VALIDATION_PASSED=false
fi

echo ""
if [ "$VALIDATION_PASSED" == true ]; then
    echo -e "${GREEN}=== VALIDATION PASSED ===${NC}"
    echo "The Composition correctly references the XRD"
else
    echo -e "${RED}=== VALIDATION FAILED ===${NC}"
    echo "The Composition does not correctly reference the XRD"
    exit 1
fi
```

fi

echo “”
echo “Tip: Use Crossview for graphical visualization”
echo “  kubectl port-forward -n crossview svc/crossview 8080:3000”
echo “  Then open: http://localhost:8080”
