#!/bin/bash

# Setup Guestbook Application Script
# This script creates an ArgoCD Application for the guestbook workload

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if repository URL is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Repository URL is required${NC}"
    echo "Usage: $0 <REPOSITORY_URL> [APPLICATION_NAME]"
    echo ""
    echo "Example:"
    echo "  $0 https://github.com/user/repo.git"
    echo "  $0 https://github.com/user/repo.git my-guestbook"
    exit 1
fi

REPO_URL="$1"
APP_NAME="${2:-guestbook}"

echo "🚀 Setting up ArgoCD Application: $APP_NAME"

# Check if argocd CLI is installed
if ! command -v argocd &> /dev/null; then
    echo -e "${YELLOW}⚠️  ArgoCD CLI not found. Creating application via kubectl instead...${NC}"
    
    # Create application using kubectl
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: manifests/guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
EOF
    
    echo -e "${GREEN}✅ Application created via kubectl${NC}"
    echo ""
    echo "To sync the application, run:"
    echo "  kubectl get application $APP_NAME -n argocd"
    echo "  # Or use ArgoCD UI to sync"
    exit 0
fi

# Check if logged in to ArgoCD
if ! argocd account get &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to ArgoCD. Please login first:${NC}"
    echo "  argocd login localhost:8080 --username admin --insecure"
    echo ""
    echo "Or create the application manually via UI or kubectl"
    exit 1
fi

# Register repository if not exists
echo "📚 Checking repository registration..."
if ! argocd repo get "$REPO_URL" &> /dev/null; then
    echo "➕ Registering repository..."
    argocd repo add "$REPO_URL" --name "$(basename $REPO_URL .git)"
fi

# Create application
echo "📱 Creating application: $APP_NAME"
argocd app create "$APP_NAME" \
  --repo "$REPO_URL" \
  --path manifests/guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook \
  --sync-policy automated \
  --auto-prune \
  --self-heal \
  --sync-option CreateNamespace=true

echo -e "${GREEN}✅ Application '$APP_NAME' created successfully!${NC}"
echo ""
echo "To view the application:"
echo "  argocd app get $APP_NAME"
echo ""
echo "To sync immediately:"
echo "  argocd app sync $APP_NAME"

