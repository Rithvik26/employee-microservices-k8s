#!/bin/bash
set -e

echo "🏢 Setting up Donato-style Professional Development Environment..."
echo "📦 This simulates enterprise AWS EKS environment locally"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Bulletproof Docker wait function (from GitHub issues research)
wait_for_docker() {
    echo "⏳ Waiting for Docker daemon to be ready..."
    local max_wait=300  # 5 minutes max wait
    local counter=0
    
    while [ $counter -lt $max_wait ]; do
        if docker ps > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Docker is ready!${NC}"
            return 0
        fi
        
        # Try to start Docker daemon if it's not running
        if [ $counter -eq 30 ] && ! pgrep -f dockerd > /dev/null; then
            echo "🔄 Attempting to start Docker daemon..."
            sudo dockerd > /tmp/dockerd.log 2>&1 &
            sleep 10
        fi
        
        if [ $((counter % 10)) -eq 0 ]; then
            echo "⏳ Still waiting for Docker... ($counter/${max_wait}s)"
        fi
        
        sleep 1
        counter=$((counter + 1))
    done
    
    echo -e "${RED}❌ Docker failed to start after ${max_wait} seconds${NC}"
    echo "📋 Docker daemon log:"
    cat /tmp/dockerd.log 2>/dev/null || echo "No docker log available"
    return 1
}

# Test Docker functionality thoroughly
test_docker() {
    echo "🔍 Testing Docker functionality..."
    
    # Test basic Docker commands
    if ! docker version > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker version check failed${NC}"
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker info check failed${NC}"
        return 1
    fi
    
    # Test Docker with a simple container
    if ! docker run --rm hello-world > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker test container failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Docker is working correctly!${NC}"
    return 0
}

# Main Docker initialization
echo "🐳 Initializing Docker environment..."
if ! wait_for_docker; then
    echo -e "${RED}❌ Failed to initialize Docker${NC}"
    exit 1
fi

if ! test_docker; then
    echo -e "${RED}❌ Docker functionality test failed${NC}"
    exit 1
fi

# Install kind if not present
echo "⚙️ Installing Kubernetes-in-Docker (kind)..."
if ! command -v kind &> /dev/null; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo -e "${GREEN}✅ kind installed successfully${NC}"
else
    echo -e "${GREEN}✅ kind is already installed${NC}"
fi

# Install Helm if not present
echo "📊 Installing Helm (enterprise Kubernetes package manager)..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo -e "${GREEN}✅ Helm installed successfully${NC}"
else
    echo -e "${GREEN}✅ Helm is already installed${NC}"
fi

# Clean up any existing cluster
if kind get clusters 2>/dev/null | grep -q "donato-microservices"; then
    echo "🧹 Cleaning up existing cluster..."
    kind delete cluster --name donato-microservices
fi

# Create professional multi-node cluster with IPv6 disabled for Codespaces compatibility
echo "🚀 Creating enterprise-style Kubernetes cluster (IPv6 disabled for Codespaces)..."
cat <<EOF | kind create cluster --name donato-microservices --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: ipv4
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  disableDefaultCNI: false
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  - |
    kind: ClusterConfiguration
    networking:
      serviceSubnet: "10.96.0.0/16"
      podSubnet: "10.244.0.0/16"
    apiServer:
      extraArgs:
        enable-admission-plugins: "NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook"
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
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-type=worker"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-type=worker"
EOF

# Verify cluster creation
echo "🔍 Verifying cluster creation..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Cluster creation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes cluster created successfully!${NC}"

# Install NGINX Ingress Controller
echo "🌐 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Install Metrics Server for HPA
echo "📈 Installing Metrics Server for auto-scaling..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for kind compatibility
kubectl patch -n kube-system deployment metrics-server --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add", 
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP"
  }
]'

# Wait for ingress controller to be ready
echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo -e "${GREEN}✅ Professional Development Environment Ready!${NC}"
echo ""
echo "🎯 Cluster Information:"
kubectl cluster-info
echo ""
echo "📊 Available Nodes:"
kubectl get nodes -o wide
echo ""
echo "🏭 System Pods Status:"
kubectl get pods -A --field-selector=status.phase!=Running | head -10
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "   1. Run: ${YELLOW}./scripts/build-microservices.sh${NC}"
echo "   2. Run: ${YELLOW}./scripts/deploy-to-kubernetes.sh${NC}"
echo "   3. Run: ${YELLOW}./scripts/test-professional-system.sh${NC}"
echo ""
echo -e "${BLUE}💡 Professional Talking Points for Interviews:${NC}"
echo "   ✅ Multi-node Kubernetes cluster with proper networking"
echo "   ✅ NGINX Ingress Controller for enterprise load balancing" 
echo "   ✅ Metrics Server for Horizontal Pod Autoscaling"
echo "   ✅ IPv4-only networking (Codespaces compatible)"
echo "   ✅ Enterprise-grade monitoring and observability"
echo ""
echo -e "${GREEN}🎉 Your professional microservices platform is ready for development!${NC}"