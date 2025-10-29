#!/bin/bash

# Cleanup Script for ArgoCD Tutorial
# This script removes the tutorial applications (guestbook and pingpong) and optionally ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLEANUP_ARGOCD="${1:-no}"

echo "🧹 ArgoCD Tutorial Cleanup"
echo ""

# Function to confirm action
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# List of applications to cleanup
APPS=("guestbook" "pingpong")

# Delete applications
for APP_NAME in "${APPS[@]}"; do
    if kubectl get application "$APP_NAME" -n argocd &> /dev/null; then
        echo -e "${YELLOW}📱 Found application: $APP_NAME${NC}"
        if confirm "Delete the application '$APP_NAME'? (This will delete all managed resources)"; then
            echo "🗑️  Deleting application..."
            
            # Try using CLI first
            if command -v argocd &> /dev/null && argocd account get &> /dev/null; then
                argocd app delete "$APP_NAME" --yes || true
            else
                kubectl delete application "$APP_NAME" -n argocd || true
            fi
            
            echo -e "${GREEN}✅ Application '$APP_NAME' deleted${NC}"
        fi
    else
        echo -e "${YELLOW}ℹ️  Application '$APP_NAME' not found${NC}"
    fi
    echo ""
done

# Delete namespaces directly (in case application deletion didn't remove them)
NAMESPACES=("guestbook" "pingpong")
for NS in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NS" &> /dev/null; then
        if confirm "Remove the '$NS' namespace?"; then
            echo "🗑️  Deleting namespace..."
            kubectl delete namespace "$NS" || true
            echo -e "${GREEN}✅ Namespace '$NS' deleted${NC}"
        fi
    fi
    echo ""
done

# Cleanup ArgoCD if requested
if [ "$CLEANUP_ARGOCD" = "yes" ] || [ "$CLEANUP_ARGOCD" = "y" ]; then
    echo ""
    if confirm "⚠️  Remove ArgoCD completely? (This will delete the entire argocd namespace)"; then
        echo "🗑️  Uninstalling ArgoCD..."
        kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
        kubectl delete namespace argocd || true
        echo -e "${GREEN}✅ ArgoCD uninstalled${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}ℹ️  ArgoCD is still running${NC}"
    echo "To uninstall ArgoCD, run:"
    echo "  $0 yes"
fi

echo ""
echo -e "${GREEN}✨ Cleanup complete!${NC}"
echo ""
echo "To stop the Kubernetes cluster:"
echo "  Minikube: minikube stop"
echo "  Kind: kind delete cluster --name argocd-demo"

