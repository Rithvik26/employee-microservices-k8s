#!/bin/bash
set -e

echo "🏢 Setting up Donato-style Professional Development Environment..."
echo "📦 This simulates enterprise AWS EKS environment locally"

# Wait for Docker to be ready
echo "⏳ Waiting for Docker to start..."
for i in {1..60}; do
    if docker version > /dev/null 2>&1; then
        echo "✅ Docker is ready!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Docker failed to start after 5 minutes"
        echo "Trying to start Docker service..."
        sudo service docker start || true
        sleep 10
        if docker version > /dev/null 2>&1; then
            echo "✅ Docker is now ready!"
            break
        else
            echo "❌ Docker still not available. Please start Docker manually."
            exit 1
        fi
    fi
    echo "Waiting for Docker... ($i/60)"
    sleep 5
done

# Verify Docker is working
echo "🔍 Testing Docker functionality..."
if ! docker run --rm hello-world > /dev/null 2>&1; then
    echo "❌ Docker test failed. Trying to fix..."
    sudo service docker restart
    sleep 10
    if ! docker run --rm hello-world > /dev/null 2>&1; then
        echo "❌ Docker is not working properly"
        exit 1
    fi
fi
echo "✅ Docker is working correctly!"

# Install kind (simulates AWS EKS cluster)
echo "⚙️  Installing Kubernetes-in-Docker (kind)..."
if ! command -v kind &> /dev/null; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "✅ kind installed successfully"
else
    echo "✅ kind is already installed"
fi

# Install Helm (enterprise package manager)
echo "📊 Installing Helm (enterprise Kubernetes package manager)..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm installed successfully"
else
    echo "✅ Helm is already installed"
fi

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "donato-microservices"; then
    echo "🔄 Kubernetes cluster 'donato-microservices' already exists"
    echo "🧹 Cleaning up existing cluster..."
    kind delete cluster --name donato-microservices
fi

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

# Verify cluster creation
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Cluster creation failed"
    exit 1
fi

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