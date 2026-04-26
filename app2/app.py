"""
Mini-Cloud Worker Node Application
===================================
Simulasi IaaS Worker Node dengan:
- Health check endpoint
- Request counter (per-node)
- Redis cache integration
- CPU/Memory metrics
- Static asset simulation (CDN demo)
"""

import os
import time
import socket
import hashlib
import psutil
from datetime import datetime
from flask import Flask, jsonify, request
import redis

app = Flask(__name__)

# ==========================================
# Konfigurasi Node
# ==========================================
NODE_ID    = os.environ.get('NODE_ID', 'unknown-node')
NODE_COLOR = os.environ.get('NODE_COLOR', '#95a5a6')
REDIS_HOST = os.environ.get('REDIS_HOST', 'redis-cache')
REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))
HOSTNAME   = socket.gethostname()
START_TIME = datetime.now()

# ==========================================
# Redis Connection (Cache Layer)
# ==========================================
def get_redis():
    try:
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT,
                        decode_responses=True, socket_timeout=2)
        r.ping()
        return r
    except Exception:
        return None

# ==========================================
# Helper: increment request counter
# ==========================================
def track_request():
    r = get_redis()
    if r:
        r.incr(f'requests:{NODE_ID}')
        r.incr('requests:total')

# ==========================================
# Routes
# ==========================================

@app.route('/')
def index():
    """Main endpoint - menampilkan info node yang melayani request"""
    track_request()

    r = get_redis()
    node_requests = int(r.get(f'requests:{NODE_ID}') or 0) if r else 0
    total_requests = int(r.get('requests:total') or 0) if r else 0
    cache_status = 'connected' if r else 'disconnected'

    # Simulasi processing time
    time.sleep(0.01)

    return jsonify({
        "status": "OK",
        "message": f"Hello dari {NODE_ID}!",
        "node": {
            "id": NODE_ID,
            "hostname": HOSTNAME,
            "color": NODE_COLOR,
            "uptime_seconds": int((datetime.now() - START_TIME).total_seconds()),
        },
        "metrics": {
            "node_requests_served": node_requests,
            "total_cluster_requests": total_requests,
            "cpu_percent": psutil.cpu_percent(interval=0.1),
            "memory_percent": psutil.virtual_memory().percent,
        },
        "infrastructure": {
            "cache_layer": cache_status,
            "timestamp": datetime.now().isoformat(),
        }
    })


@app.route('/health')
def health():
    """Health check endpoint - digunakan oleh Nginx untuk node monitoring"""
    r = get_redis()
    redis_ok = r is not None

    status = 200 if redis_ok else 206  # 206 = degraded tapi masih bisa serve

    return jsonify({
        "status": "healthy" if redis_ok else "degraded",
        "node_id": NODE_ID,
        "hostname": HOSTNAME,
        "checks": {
            "application": "OK",
            "redis_cache": "connected" if redis_ok else "disconnected",
        },
        "timestamp": datetime.now().isoformat()
    }), status


@app.route('/cache-demo')
def cache_demo():
    """
    Demo Redis Caching:
    - Pertama kali: compute data baru (lambat) dan simpan ke cache
    - Kedua kali: ambil dari cache (cepat)
    """
    cache_key = 'demo:heavy-computation'
    r = get_redis()

    cache_hit = False
    data = None

    if r:
        cached = r.get(cache_key)
        if cached:
            data = cached
            cache_hit = True

    if not data:
        # Simulasi heavy computation (database query, dll)
        time.sleep(0.5)
        data = hashlib.sha256(f"computed-at-{datetime.now()}".encode()).hexdigest()
        if r:
            r.setex(cache_key, 30, data)  # Cache selama 30 detik

    return jsonify({
        "result": data,
        "cache_hit": cache_hit,
        "cache_source": "redis" if cache_hit else "computed",
        "served_by": NODE_ID,
        "message": "CACHE HIT - data dari Redis!" if cache_hit else "CACHE MISS - data baru dicompute"
    })


@app.route('/static/asset')
def static_asset():
    """
    Simulasi CDN Static Asset Delivery
    Nginx akan cache response ini lebih lama (5 menit)
    """
    return jsonify({
        "asset": "logo.png",
        "size_kb": 42,
        "content_type": "image/png",
        "cdn_node": NODE_ID,
        "cache_control": "public, max-age=300",
        "message": "Static asset - akan di-cache oleh Nginx (simulasi CDN)"
    })


@app.route('/no-cache')
def no_cache():
    """Endpoint tanpa cache - selalu dari origin server"""
    track_request()
    return jsonify({
        "node_id": NODE_ID,
        "time": datetime.now().isoformat(),
        "message": "Data real-time - tidak di-cache",
        "random_id": int(time.time() * 1000)
    })


@app.route('/load-test')
def load_test():
    """Simulasi CPU-intensive task untuk demo elasticity"""
    # CPU-bound computation
    start = time.time()
    result = sum(i * i for i in range(100000))
    elapsed = time.time() - start

    return jsonify({
        "node_id": NODE_ID,
        "computation_time_ms": round(elapsed * 1000, 2),
        "result_checksum": result % 1000,
        "cpu_after": psutil.cpu_percent(interval=0.1),
    })


@app.route('/metrics')
def metrics():
    """Prometheus-format metrics endpoint"""
    r = get_redis()
    node_requests = int(r.get(f'requests:{NODE_ID}') or 0) if r else 0

    metrics_text = f"""# HELP node_requests_total Total requests served by this node
# TYPE node_requests_total counter
node_requests_total{{node="{NODE_ID}"}} {node_requests}

# HELP node_cpu_percent CPU usage percent
# TYPE node_cpu_percent gauge
node_cpu_percent{{node="{NODE_ID}"}} {psutil.cpu_percent()}

# HELP node_memory_percent Memory usage percent
# TYPE node_memory_percent gauge
node_memory_percent{{node="{NODE_ID}"}} {psutil.virtual_memory().percent}
"""
    return metrics_text, 200, {'Content-Type': 'text/plain'}


if __name__ == '__main__':
    print(f"[{NODE_ID}] Starting worker node on port 5000...")
    print(f"[{NODE_ID}] Redis: {REDIS_HOST}:{REDIS_PORT}")
    app.run(host='0.0.0.0', port=5000, debug=False)
