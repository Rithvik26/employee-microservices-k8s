#!/bin/bash
set -e

echo "🚀 Deploying to Kubernetes - Professional Enterprise Pattern"

# Create namespace with labels (enterprise pattern)
echo "🏢 Creating employee-platform namespace..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: employee-platform
  labels:
    environment: development
    team: platform-engineering
    project: employee-microservices
EOF

# Create professional PostgreSQL deployment
echo "🐘 Deploying PostgreSQL with enterprise configuration..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-script
  namespace: employee-platform
data:
  init.sql: |
    -- Professional database schema
    CREATE TABLE IF NOT EXISTS employees (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        department VARCHAR(50) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
    CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);
    CREATE INDEX IF NOT EXISTS idx_employees_created_at ON employees(created_at);
    
    -- Insert professional test data
    INSERT INTO employees (name, email, department) VALUES 
    ('John Smith', 'john.smith@company.com', 'Engineering'),
    ('Sarah Johnson', 'sarah.johnson@company.com', 'Product Management'),
    ('Mike Chen', 'mike.chen@company.com', 'Design'),
    ('Emily Rodriguez', 'emily.rodriguez@company.com', 'DevOps'),
    ('David Kumar', 'david.kumar@company.com', 'QA Engineering')
    ON CONFLICT (email) DO NOTHING;
    
    -- Professional database statistics
    ANALYZE employees;
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: employee-platform
type: Opaque
stringData:
  username: admin
  password: SecurePassword123!
  database: employeedb
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: employee-platform
  labels:
    app: postgres
    tier: database
    version: v13
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: database
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
              - pg_isready
              - -h
              - localhost
              - -U
              - admin
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
              - pg_isready
              - -h
              - localhost
              - -U
              - admin
          initialDelaySeconds: 10
          periodSeconds: 5
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: postgres-storage
        emptyDir: {}
      - name: init-script
        configMap:
          name: postgres-init-script
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: employee-platform
  labels:
    app: postgres
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
EOF

echo "🔄 Deploying Redis with professional configuration..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: employee-platform
  labels:
    app: redis
    tier: cache
    version: v7
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
          - redis-server
          - --maxmemory
          - "256mb"
          - --maxmemory-policy
          - "allkeys-lru"
        ports:
        - containerPort: 6379
          name: redis
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
              - redis-cli
              - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
              - redis-cli
              - ping
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: employee-platform
  labels:
    app: redis
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
EOF

echo "⏳ Waiting for databases to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n employee-platform --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis -n employee-platform --timeout=120s

echo "👥 Deploying User Service with professional patterns..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: employee-platform
  labels:
    app: user-service
    tier: application
    version: v1.0.0
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        tier: application
        version: v1.0.0
    spec:
      containers:
      - name: user-service
        image: employee-platform/user-service:v1.0.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: DB_HOST
          value: postgres-service
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: database
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: REDIS_HOST
          value: redis-service
        - name: CACHE_TTL
          value: "300"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 45
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 15
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: employee-platform
  labels:
    app: user-service
spec:
  type: ClusterIP
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 5000
    name: http
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: employee-platform
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
EOF

echo "📨 Deploying Notification Service with event handling..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: employee-platform
  labels:
    app: notification-service
    tier: application
    version: v1.0.0
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: notification-service
  template:
    metadata:
      labels:
        app: notification-service
        tier: application
        version: v1.0.0
    spec:
      containers:
      - name: notification-service
        image: employee-platform/notification-service:v1.0.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5001
          name: http
        env:
        - name: REDIS_HOST
          value: redis-service
        - name: REDIS_PORT
          value: "6379"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5001
          initialDelaySeconds: 45
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 5001
          initialDelaySeconds: 15
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 5001
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: employee-platform
  labels:
    app: notification-service
spec:
  type: ClusterIP
  selector:
    app: notification-service
  ports:
  - port: 80
    targetPort: 5001
    name: http
EOF

echo "🌐 Creating professional ingress configuration..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: employee-platform-ingress
  namespace: employee-platform
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /user-service(/|\$)(.*)
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 80
      - path: /notification-service(/|\$)(.*)
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 80
EOF

echo "⏳ Waiting for all services to be ready..."
kubectl wait --for=condition=ready pod -l app=user-service -n employee-platform --timeout=120s
kubectl wait --for=condition=ready pod -l app=notification-service -n employee-platform --timeout=120s

echo "✅ Professional Deployment Complete!"
echo ""
echo "📊 System Status:"
kubectl get pods -n employee-platform -o wide
echo ""
echo "🌐 Services:"
kubectl get services -n employee-platform
echo ""
echo "📈 Auto-scaling Status:"
kubectl get hpa -n employee-platform
echo ""
echo "🔗 Ingress Status:"
kubectl get ingress -n employee-platform
echo ""
echo "🎯 Access Points:"
echo "   • User Service Health: http://localhost:8080/user-service/health"
echo "   • Notification Service Health: http://localhost:8080/notification-service/health"
echo "   • Employee API: http://localhost:8080/user-service/api/employees"
echo "   • Notifications API: http://localhost:8080/notification-service/api/notifications"
echo ""
echo "🚀 Next: Run ./scripts/test-professional-system.sh"