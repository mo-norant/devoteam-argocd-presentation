#!/bin/bash

# ArgoCD Installation Script
# This script installs ArgoCD in a dedicated namespace using Kubernetes manifests

set -e

echo "🚀 Starting ArgoCD installation..."

# Create namespace
echo "📦 Creating argocd namespace..."
kubectl create namespace argocd || echo "Namespace argocd already exists"

# Install ArgoCD
echo "📥 Installing ArgoCD from official manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Display pod status
echo "✅ ArgoCD installation complete!"
echo ""
echo "📊 Pod status:"
kubectl get pods -n argocd

echo ""
echo "🔐 To get the admin password, run:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo"
echo ""
echo "🌐 To access the UI, run:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "   Then open: https://localhost:8080"
echo "   Username: admin"
echo "   Password: (use command above)"

