#!/bin/bash

# Rollback Script for ArgoCD Application
# This script demonstrates rollback functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="${1:-guestbook}"

echo "🔄 ArgoCD Rollback Demonstration"
echo "Application: $APP_NAME"
echo ""

# Check if argocd CLI is installed
if ! command -v argocd &> /dev/null; then
    echo -e "${RED}❌ Error: ArgoCD CLI is required for this script${NC}"
    echo ""
    echo "Please install ArgoCD CLI first:"
    echo "  Linux/macOS: brew install argocd"
    echo "  Or download from: https://github.com/argoproj/argo-cd/releases"
    exit 1
fi

# Check if logged in
if ! argocd account get &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to ArgoCD${NC}"
    echo "Please login first:"
    echo "  argocd login localhost:8080 --username admin --insecure"
    exit 1
fi

# Check if application exists
if ! argocd app get "$APP_NAME" &> /dev/null; then
    echo -e "${RED}❌ Error: Application '$APP_NAME' not found${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Sync History:${NC}"
echo ""
argocd app history "$APP_NAME"

echo ""
echo -e "${YELLOW}ℹ️  To rollback to a specific revision:${NC}"
echo "  1. Copy the REVISION ID from the history above"
echo "  2. Run: argocd app rollback $APP_NAME <REVISION_ID>"
echo ""
echo -e "${YELLOW}ℹ️  Or manually rollback via Git (GitOps best practice):${NC}"
echo "  1. Check commit history: git log manifests/guestbook/"
echo "  2. Revert commit: git revert HEAD"
echo "  3. Push: git push origin main"
echo "  4. ArgoCD will auto-sync the change"
echo ""
read -p "Enter REVISION ID to rollback (or press Enter to cancel): " REVISION_ID

if [ -z "$REVISION_ID" ]; then
    echo "Rollback cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}⚠️  Rolling back to revision: $REVISION_ID${NC}"
argocd app rollback "$APP_NAME" "$REVISION_ID"

echo ""
echo -e "${GREEN}✅ Rollback initiated!${NC}"
echo ""
echo "To monitor the rollback:"
echo "  argocd app get $APP_NAME"
echo "  watch argocd app get $APP_NAME"

