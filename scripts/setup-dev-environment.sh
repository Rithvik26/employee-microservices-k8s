#!/bin/bash
set -e

echo "🏢 Setting up Donato-style Professional Development Environment..."
echo "📦 This simulates enterprise AWS EKS environment locally"

# Wait for Docker to be ready
echo "⏳ Waiting for Docker to start..."
for i in {1..30}; do
    if docker version > /dev/null 2>&1; then
        echo "✅ Docker is ready!"
        break
    fi
    echo "Waiting for Docker... ($i/30)"
    sleep 2
done

# Install kind (simulates AWS EKS cluster)
echo "⚙️  Installing Kubernetes-in-Docker (kind)..."
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install Helm (enterprise package manager)
echo "📊 Installing Helm (enterprise Kubernetes package manager)..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create professional multi-node cluster config
echo "🚀 Creating enterprise-style Kubernetes cluster..."
cat <<EOF | kind create cluster --name donato-microservices --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 8081
    hostPort: 8081
    protocol: TCP
  - containerPort: 8082
    hostPort: 8082
    protocol: TCP
- role: worker
- role: worker
EOF

# Install NGINX Ingress (like enterprise load balancer)
echo "🌐 Installing NGINX Ingress Controller (enterprise load balancing)..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Install metrics server (for professional monitoring)
echo "📈 Installing Metrics Server (for HPA and monitoring)..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch -n kube-system deployment metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait for ingress to be ready
echo "⏳ Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "✅ Professional Development Environment Ready!"
echo ""
echo "🎯 Cluster Information:"
kubectl cluster-info
echo ""
echo "📊 Available Nodes:"
kubectl get nodes
echo ""
echo "🚀 Next Steps:"
echo "   1. Run: ./scripts/build-microservices.sh"
echo "   2. Run: ./scripts/deploy-to-kubernetes.sh"
echo "   3. Run: ./scripts/test-professional-system.sh"
echo ""
echo "💡 Professional Talking Points for Interviews:"
echo "   ✅ Multi-node Kubernetes cluster"
echo "   ✅ NGINX Ingress Controller"
echo "   ✅ Metrics Server for HPA"
echo "   ✅ Enterprise-grade monitoring"