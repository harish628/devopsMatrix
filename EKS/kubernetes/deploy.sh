#!/bin/sh
set -eu

: "${AWS_REGION:=${AWS_DEFAULT_REGION:-}}"
: "${AWS_REGION:?Set AWS_REGION or AWS_DEFAULT_REGION}"
: "${IMAGE_URI:?Set IMAGE_URI to the pushed container image URI}"

EKS_CLUSTER=${EKS_CLUSTER:-eksCluster}
K8S_NAMESPACE=static-site
ROLLOUT_TIMEOUT=${ROLLOUT_TIMEOUT:-10m}
LOAD_BALANCER_TIMEOUT=${LOAD_BALANCER_TIMEOUT:-10m}

case "$IMAGE_URI" in
    *'|'*|*'&'*|*[!A-Za-z0-9./:@_-]*)
        echo "IMAGE_URI contains characters that cannot be safely rendered into the manifest." >&2
        exit 2
        ;;
esac

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)

aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"

kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
sed "s|placeholder/static-site:placeholder|$IMAGE_URI|g" "$SCRIPT_DIR/deployment.yaml" | kubectl apply -f -
kubectl apply -n "$K8S_NAMESPACE" -f "$SCRIPT_DIR/service.yaml"

kubectl rollout status deployment/static-site \
    --namespace "$K8S_NAMESPACE" \
    --timeout="$ROLLOUT_TIMEOUT"
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' \
    service/static-site-service \
    --namespace "$K8S_NAMESPACE" \
    --timeout="$LOAD_BALANCER_TIMEOUT"
kubectl get service static-site-service --namespace "$K8S_NAMESPACE" -o wide