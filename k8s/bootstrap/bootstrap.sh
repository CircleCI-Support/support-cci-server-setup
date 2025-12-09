#!/bin/bash
set -e

if [ -z "$REPO_URL" ]; then
  echo "Error: REPO_URL environment variable not set"
  echo "Export it with: export REPO_URL=https://github.com/kurtassad/support-cci-server-setup.git"
  exit 1
fi

# Check if sealed-secrets-key.yaml exists
SEALED_SECRETS_KEY="$(dirname "${BASH_SOURCE[0]}")/../../secrets/sealed-secrets-key.yaml"

if [ ! -f "$SEALED_SECRETS_KEY" ]; then
  echo "Error: sealed-secrets-key.yaml not found at $SEALED_SECRETS_KEY"
  echo "Please ensure the sealed-secrets-key.yaml file exists in the secrets directory"
  exit 1
fi

echo "Found sealed-secrets-key.yaml, applying to cluster..."
# Delete existing secret if it exists to avoid conflicts, then apply
kubectl delete -f "$SEALED_SECRETS_KEY" 2>/dev/null || true
kubectl apply -f "$SEALED_SECRETS_KEY"

kubectl create namespace argocd || true

# No secret needed for public repository - ArgoCD can access it directly

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --version 9.1.3 \
  --namespace argocd \
  --wait

kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

envsubst < app-of-apps.yaml | kubectl apply -f -

# Wait for ArgoCD to be ready and then apply CircleCI app
echo "Waiting for ArgoCD to be ready..."
sleep 10