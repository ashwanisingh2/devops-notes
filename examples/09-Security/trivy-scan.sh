#!/bin/bash
# ==============================================================================
# DevSecOps Pipeline Simulation: Trivy Container Scan
# Fails the pipeline if CRITICAL vulnerabilities are found (with fix available)
# ==============================================================================
set -e

IMAGE_NAME=${1:-"nginx:1.18.0"}

echo "------------------------------------------------------"
echo "🔍 Starting Trivy Vulnerability Scan on: $IMAGE_NAME"
echo "------------------------------------------------------"

# Run Trivy Scan
# --exit-code 1: Fails the script if vulns are found
# --severity CRITICAL: Only block on CRITICAL findings
# --ignore-unfixed: Do not block developers if no patch exists in the world yet
trivy image \
    --exit-code 1 \
    --severity CRITICAL \
    --ignore-unfixed \
    $IMAGE_NAME

SCAN_EXIT_CODE=$?

if [ $SCAN_EXIT_CODE -eq 0 ]; then
    echo "✅ Scan Passed! No fixable CRITICAL vulnerabilities found."
    echo "Proceeding to next pipeline stage (e.g., Push to Registry)."
else
    echo "❌ SECURITY GATE FAILED! Fix the vulnerabilities before merging code."
    exit 1
fi
