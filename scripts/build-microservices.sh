
#!/bin/bash
set -e

echo "🏗️ Building Professional Microservices (Enterprise Pattern)..."

# Create professional directory structure
mkdir -p services/{user-service,notification-service}
mkdir -p infrastructure/{kubernetes,monitoring}
mkdir -p tests/{integration,load}

echo "👥 Building User Service (Employee Management)..."

# User Service - Professional Flask Application
cat > services/user-service/app.py << 'EOF'
from flask import Flask, request, jsonify
import psycopg2
import redis
import json
import os
import logging
from datetime import datetime
from contextlib import contextmanager

# Professional logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Professional configuration management
class Config:
    DB_HOST = os.getenv('DB_HOST', 'postgres-service')
    DB_NAME = os.getenv('DB_NAME', 'employeedb')
    DB_USER = os.getenv('DB_USER', 'admin')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'password')
    REDIS_HOST = os.getenv('REDIS_HOST', 'redis-service')
    REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
    CACHE_TTL = int(os.getenv('CACHE_TTL', '300'))  # 5 minutes

@contextmanager
def get_db_connection():
    """Professional database connection with proper cleanup"""
    conn = None
    try:
        conn = psycopg2.connect(
            host=Config.DB_HOST,
            database=Config.DB_NAME,
            user=Config.DB_USER,
            password=Config.DB_PASSWORD,
            connect_timeout=10
        )
        yield conn
    except psycopg2.Error as e:
        logger.error(f"Database error: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()

def get_redis_client():
    """Professional Redis client with error handling"""
    try:
        client = redis.Redis(
            host=Config.REDIS_HOST,
            port=Config.REDIS_PORT,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5
        )
        # Test connection
        client.ping()
        return client
    except redis.ConnectionError as e:
        logger.error(f"Redis connection failed: {e}")
        return None

@app.route('/health', methods=['GET'])
def health_check():
    """Professional health endpoint for Kubernetes probes"""
    health_status = {
        "status": "healthy",
        "service": "user-service",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "checks": {}
    }
    
    # Database health check
    try:
        with get_db_connection() as conn:
            cur = conn.cursor()
            cur.execute('SELECT 1')
            health_status["checks"]["database"] = "healthy"
    except Exception as e:
        health_status["checks"]["database"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Redis health check
    redis_client = get_redis_client()
    if redis_client:
        try:
            redis_client.ping()
            health_status["checks"]["redis"] = "healthy"
        except:
            health_status["checks"]["redis"] = "unhealthy"
    else:
        health_status["checks"]["redis"] = "unavailable"
    
    status_code = 200 if health_status["status"] == "healthy" else 503
    return jsonify(health_status), status_code

@app.route('/api/employees', methods=['GET'])
def get_employees():
    """Professional endpoint with caching and error handling"""
    try:
        redis_client = get_redis_client()
        
        # Check cache first (enterprise caching pattern)
        if redis_client:
            try:
                cached = redis_client.get('employees:all')
                if cached:
                    logger.info("Serving employees from cache")
                    return jsonify({
                        "data": json.loads(cached),
                        "source": "cache",
                        "count": len(json.loads(cached)),
                        "cached_at": redis_client.get('employees:cached_at')
                    })
            except Exception as e:
                logger.warning(f"Cache read error: {e}")
        
        # Fetch from database
        with get_db_connection() as conn:
            cur = conn.cursor()
            cur.execute('''
                SELECT id, name, email, department, created_at 
                FROM employees 
                ORDER BY created_at DESC
            ''')
            employees = cur.fetchall()
            
            result = []
            for emp in employees:
                result.append({
                    "id": emp[0],
                    "name": emp[1],
                    "email": emp[2],
                    "department": emp[3],
                    "created_at": emp[4].isoformat() if emp[4] else None
                })
            
            # Cache the results (enterprise pattern)
            if redis_client:
                try:
                    cache_time = datetime.now().isoformat()
                    redis_client.setex('employees:all', Config.CACHE_TTL, json.dumps(result))
                    redis_client.setex('employees:cached_at', Config.CACHE_TTL, cache_time)
                    logger.info(f"Cached {len(result)} employees for {Config.CACHE_TTL}s")
                except Exception as e:
                    logger.warning(f"Cache write error: {e}")
            
            logger.info(f"Served {len(result)} employees from database")
            return jsonify({
                "data": result,
                "source": "database",
                "count": len(result)
            })
            
    except Exception as e:
        logger.error(f"Error fetching employees: {e}")
        return jsonify({
            "error": "Internal server error",
            "message": "Unable to fetch employees"
        }), 500

@app.route('/api/employees', methods=['POST'])
def create_employee():
    """Professional endpoint with validation and event publishing"""
    try:
        data = request.get_json()
        
        # Comprehensive validation
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        required_fields = ['name', 'email', 'department']
        missing_fields = [field for field in required_fields if not data.get(field)]
        if missing_fields:
            return jsonify({
                "error": "Missing required fields",
                "missing": missing_fields
            }), 400
        
        # Email validation
        if '@' not in data['email'] or '.' not in data['email']:
            return jsonify({"error": "Invalid email format"}), 400
        
        # Create employee
        with get_db_connection() as conn:
            cur = conn.cursor()
            
            # Check for duplicate email
            cur.execute('SELECT id FROM employees WHERE email = %s', (data['email'],))
            if cur.fetchone():
                return jsonify({"error": "Employee with this email already exists"}), 409
            
            # Insert new employee
            cur.execute('''
                INSERT INTO employees (name, email, department) 
                VALUES (%s, %s, %s) 
                RETURNING id, created_at
            ''', (data['name'], data['email'], data['department']))
            
            employee_id, created_at = cur.fetchone()
            conn.commit()
            
            # Clear cache (enterprise pattern)
            redis_client = get_redis_client()
            if redis_client:
                try:
                    redis_client.delete('employees:all', 'employees:cached_at')
                    logger.info("Cleared employee cache after creation")
                    
                    # Publish event (enterprise event-driven pattern)
                    event = {
                        'event_type': 'employee.created',
                        'event_id': f"emp_created_{employee_id}_{int(datetime.now().timestamp())}",
                        'employee_id': employee_id,
                        'employee_name': data['name'],
                        'employee_email': data['email'],
                        'department': data['department'],
                        'timestamp': datetime.now().isoformat(),
                        'source_service': 'user-service'
                    }
                    
                    redis_client.publish('employee_events', json.dumps(event))
                    logger.info(f"Published employee.created event for ID {employee_id}")
                    
                except Exception as e:
                    logger.warning(f"Event publishing error: {e}")
            
            response_data = {
                "message": "Employee created successfully",
                "employee": {
                    "id": employee_id,
                    "name": data['name'],
                    "email": data['email'],
                    "department": data['department'],
                    "created_at": created_at.isoformat()
                }
            }
            
            logger.info(f"Created employee: {data['name']} (ID: {employee_id})")
            return jsonify(response_data), 201
            
    except Exception as e:
        logger.error(f"Error creating employee: {e}")
        return jsonify({
            "error": "Internal server error",
            "message": "Unable to create employee"
        }), 500

@app.route('/metrics', methods=['GET'])
def metrics():
    """Professional metrics endpoint for monitoring"""
    try:
        redis_client = get_redis_client()
        
        with get_db_connection() as conn:
            cur = conn.cursor()
            cur.execute('SELECT COUNT(*) FROM employees')
            total_employees = cur.fetchone()[0]
        
        cache_hits = 0
        if redis_client:
            try:
                cache_hits = int(redis_client.get('cache:hits') or 0)
            except:
                pass
        
        return jsonify({
            "total_employees": total_employees,
            "cache_hits": cache_hits,
            "service_uptime": "calculated_in_production",
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting User Service v1.0.0")
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# User Service Dockerfile (Professional)
cat > services/user-service/Dockerfile << 'EOF'
FROM python:3.9-slim

# Professional metadata
LABEL maintainer="rithvik@professional-microservices.com"
LABEL version="1.0.0"
LABEL description="User Service - Employee Management Microservice"

# Create non-root user (security best practice)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Professional health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Use exec form for proper signal handling
CMD ["python", "app.py"]
EOF

# User Service Requirements
cat > services/user-service/requirements.txt << 'EOF'
Flask==2.3.3
psycopg2-binary==2.9.7
redis==4.6.0
gunicorn==21.2.0
EOF

echo "📨 Building Notification Service (Event-Driven)..."

# Notification Service - Professional Event Handler
cat > services/notification-service/app.py << 'EOF'
from flask import Flask, request, jsonify
import redis
import json
import threading
import logging
import os
import time
from datetime import datetime
from typing import Dict, List, Optional

# Professional logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class Config:
    REDIS_HOST = os.getenv('REDIS_HOST', 'redis-service')
    REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
    NOTIFICATION_QUEUE = 'notifications:history'
    EVENT_CHANNEL = 'employee_events'
    MAX_HISTORY = 100

class NotificationService:
    def __init__(self):
        self.redis_client = self._get_redis_client()
        self.is_listening = False
        self.processed_events = 0
        
    def _get_redis_client(self) -> Optional[redis.Redis]:
        """Professional Redis client with retry logic"""
        max_retries = 3
        for attempt in range(max_retries):
            try:
                client = redis.Redis(
                    host=Config.REDIS_HOST,
                    port=Config.REDIS_PORT,
                    decode_responses=True,
                    socket_connect_timeout=5,
                    socket_timeout=5
                )
                client.ping()
                logger.info(f"Connected to Redis at {Config.REDIS_HOST}:{Config.REDIS_PORT}")
                return client
            except redis.ConnectionError as e:
                logger.warning(f"Redis connection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
        
        logger.error("Failed to connect to Redis after all attempts")
        return None

    def start_event_listener(self):
        """Professional event listener with error handling"""
        if not self.redis_client:
            logger.error("Cannot start event listener: Redis unavailable")
            return
            
        try:
            pubsub = self.redis_client.pubsub()
            pubsub.subscribe(Config.EVENT_CHANNEL)
            self.is_listening = True
            
            logger.info(f"🎧 Notification service listening on channel: {Config.EVENT_CHANNEL}")
            
            for message in pubsub.listen():
                if not self.is_listening:
                    break
                    
                if message['type'] == 'message':
                    try:
                        event_data = json.loads(message['data'])
                        self._process_event(event_data)
                        self.processed_events += 1
                    except json.JSONDecodeError as e:
                        logger.error(f"Invalid JSON in event: {e}")
                    except Exception as e:
                        logger.error(f"Event processing error: {e}")
                        
        except Exception as e:
            logger.error(f"Event listener error: {e}")
            self.is_listening = False

    def _process_event(self, event_data: Dict):
        """Process different types of business events"""
        event_type = event_data.get('event_type')
        
        if event_type == 'employee.created':
            self._handle_employee_created(event_data)
        else:
            logger.warning(f"Unknown event type: {event_type}")

    def _handle_employee_created(self, event_data: Dict):
        """Handle employee creation events with professional notification"""
        try:
            employee_name = event_data.get('employee_name', 'Unknown')
            employee_id = event_data.get('employee_id')
            department = event_data.get('department', 'Unknown')
            
            logger.info(f"📧 Processing welcome notification for {employee_name} (ID: {employee_id})")
            
            # Create comprehensive notification record
            notification = {
                'id': f"notif_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{employee_id}",
                'type': 'employee_welcome',
                'event_id': event_data.get('event_id'),
                'recipient_name': employee_name,
                'recipient_email': event_data.get('employee_email'),
                'employee_id': employee_id,
                'department': department,
                'status': 'processed',
                'channel': 'email',
                'priority': 'normal',
                'subject': f'Welcome to the team, {employee_name}!',
                'content': f'Welcome to the {department} department. We\'re excited to have you!',
                'created_at': event_data.get('timestamp'),
                'processed_at': datetime.now().isoformat(),
                'source_service': 'notification-service',
                'target_service': 'user-service'
            }
            
            # Store notification history
            if self.redis_client:
                self.redis_client.lpush(Config.NOTIFICATION_QUEUE, json.dumps(notification))
                self.redis_client.ltrim(Config.NOTIFICATION_QUEUE, 0, Config.MAX_HISTORY - 1)
                
                # Update metrics
                self.redis_client.incr('notifications:total_sent')
                
                logger.info(f"✅ Notification processed: {notification['id']}")
            
        except Exception as e:
            logger.error(f"Error handling employee created event: {e}")

# Initialize service
notification_service = NotificationService()

@app.route('/health', methods=['GET'])
def health_check():
    """Professional health endpoint"""
    health_status = {
        "status": "healthy",
        "service": "notification-service",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "checks": {}
    }
    
    # Redis health check
    if notification_service.redis_client:
        try:
            notification_service.redis_client.ping()
            health_status["checks"]["redis"] = "healthy"
        except:
            health_status["checks"]["redis"] = "unhealthy"
            health_status["status"] = "degraded"
    else:
        health_status["checks"]["redis"] = "unavailable"
        health_status["status"] = "degraded"
    
    # Event listener status
    health_status["checks"]["event_listener"] = "active" if notification_service.is_listening else "inactive"
    
    status_code = 200 if health_status["status"] == "healthy" else 503
    return jsonify(health_status), status_code

@app.route('/api/notifications', methods=['GET'])
def get_notifications():
    """Professional notifications endpoint with pagination"""
    try:
        limit = min(int(request.args.get('limit', 20)), 100)  # Max 100
        offset = int(request.args.get('offset', 0))
        
        if not notification_service.redis_client:
            return jsonify({"error": "Notification service unavailable"}), 503
            
        # Get notifications with pagination
        notifications = notification_service.redis_client.lrange(
            Config.NOTIFICATION_QUEUE, offset, offset + limit - 1
        )
        
        result = []
        for notification_json in notifications:
            try:
                result.append(json.loads(notification_json))
            except json.JSONDecodeError as e:
                logger.warning(f"Invalid notification JSON: {e}")
        
        # Get total count and metrics
        total_count = notification_service.redis_client.llen(Config.NOTIFICATION_QUEUE)
        total_sent = int(notification_service.redis_client.get('notifications:total_sent') or 0)
        
        return jsonify({
            "data": result,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "total": total_count,
                "has_more": offset + limit < total_count
            },
            "metrics": {
                "total_notifications": total_count,
                "total_sent": total_sent,
                "processed_events": notification_service.processed_events
            }
        })
        
    except Exception as e:
        logger.error(f"Error fetching notifications: {e}")
        return jsonify({
            "error": "Internal server error",
            "message": "Unable to fetch notifications"
        }), 500

@app.route('/metrics', methods=['GET'])
def metrics():
    """Professional metrics endpoint"""
    try:
        if not notification_service.redis_client:
            return jsonify({"error": "Service unavailable"}), 503
            
        total_notifications = notification_service.redis_client.llen(Config.NOTIFICATION_QUEUE)
        total_sent = int(notification_service.redis_client.get('notifications:total_sent') or 0)
        
        return jsonify({
            "total_notifications": total_notifications,
            "total_sent": total_sent,
            "processed_events": notification_service.processed_events,
            "event_listener_active": notification_service.is_listening,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Start professional event listener in background
    listener_thread = threading.Thread(target=notification_service.start_event_listener, daemon=True)
    listener_thread.start()
    
    logger.info("Starting Notification Service v1.0.0")
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

# Notification Service Dockerfile
cat > services/notification-service/Dockerfile << 'EOF'
FROM python:3.9-slim

LABEL maintainer="rithvik@professional-microservices.com"
LABEL version="1.0.0"
LABEL description="Notification Service - Event-Driven Messaging"

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Set ownership
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 5001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5001/health || exit 1

CMD ["python", "app.py"]
EOF

# Notification Service Requirements
cat > services/notification-service/requirements.txt << 'EOF'
Flask==2.3.3
redis==4.6.0
gunicorn==21.2.0
EOF

echo "🐳 Building Professional Docker Images..."

# Build User Service
echo "Building user-service:v1.0.0..."
docker build -t employee-platform/user-service:v1.0.0 services/user-service/

# Build Notification Service  
echo "Building notification-service:v1.0.0..."
docker build -t employee-platform/notification-service:v1.0.0 services/notification-service/

# Load images into kind cluster
echo "📦 Loading images into Kubernetes cluster..."
kind load docker-image employee-platform/user-service:v1.0.0 --name donato-microservices
kind load docker-image employee-platform/notification-service:v1.0.0 --name donato-microservices

echo "✅ Professional Microservices Built Successfully!"
echo ""
echo "🏗️ What was built:"
echo "   ✅ User Service with Redis caching"
echo "   ✅ Notification Service with event handling"
echo "   ✅ Professional Docker images with security best practices"
echo "   ✅ Comprehensive error handling and logging"
echo "   ✅ Health checks and metrics endpoints"
echo ""
echo "🚀 Next: Run ./scripts/deploy-to-kubernetes.sh"