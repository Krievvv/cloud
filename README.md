# Mini-Cloud Environment Simulation
**UTS Cloud Computing — Simulasi Arsitektur IDEAL & Elastic Computing dengan Docker**

---

## Topologi Infrastruktur

```
                        ┌──────────────────────────────────┐
                        │        MINI-CLOUD NETWORK        │
                        │        172.20.0.0/16             │
                        │                                  │
  [Client/Browser]      │   ┌─────────────────────────┐   │
       │                │   │   Nginx Load Balancer    │   │
       └────────────────┼──▶│   172.20.0.10 : 80       │   │
                        │   │   (CDN Entry Point)      │   │
                        │   └────────┬────────┬────────┘   │
                        │            │        │             │
                        │   ┌────────▼──┐ ┌───▼────────┐   │
                        │   │ app-node-1│ │ app-node-2 │   │
                        │   │ .20.0.21  │ │  .20.0.22  │   │
                        │   │ (Worker)  │ │  (Worker)  │   │
                        │   └─────┬─────┘ └─────┬──────┘   │
                        │         │              │           │
                        │   ┌─────▼──────────────▼──────┐   │
                        │   │      Redis Cache           │   │
                        │   │      172.20.0.30           │   │
                        │   └────────────────────────────┘   │
                        │                                  │
                        │   [Prometheus: 172.20.0.40]      │
                        └──────────────────────────────────┘
```

## Keterkaitan dengan Prinsip IDEAL

| Prinsip | Komponen | Implementasi |
|---------|----------|--------------|
| **I**solated | app-node-1, app-node-2 | Setiap container memiliki network namespace, filesystem, dan process space sendiri |
| **D**emocratic | Nginx upstream | Semua node mendapat beban yang sama (round-robin, weight=1) |
| **E**lastic | docker-compose.scale.yml | Horizontal scaling: node ke-3 ditambah tanpa downtime |
| **A**daptive | Health checks + failover | Nginx otomatis reroute jika node mati (proxy_next_upstream) |
| **L**ess-coupled | Redis + REST API | Cache layer terpisah; app hanya berkomunikasi via HTTP/Redis |

---

## Cara Menjalankan

### Prasyarat
- Docker Desktop (Windows/Mac) atau Docker Engine (Linux)
- Docker Compose v2+

### 1. Clone/Download Project
```bash
cd mini-cloud/
```

### 2. Jalankan Infrastruktur Dasar (2 Nodes)
```bash
docker-compose up -d --build
```

### 3. Verifikasi Status
```bash
docker-compose ps
docker stats --no-stream
```

### 4. Akses Aplikasi
- **Main App**: http://localhost/
- **Health Check**: http://localhost/health
- **Cache Demo**: http://localhost/cache-demo
- **Static/CDN**: http://localhost/static/asset
- **No Cache**: http://localhost/no-cache
- **Nginx Status**: http://localhost:8080/nginx_status
- **Prometheus**: http://localhost:9090

### 5. Demo Fault Tolerance
```bash
# Matikan node-1
docker stop cloud-app-node-1

# Cek - service masih berjalan via node-2
curl http://localhost/

# Hidupkan lagi
docker start cloud-app-node-1
```

### 6. Horizontal Scaling (Scale Out)
```bash
# Tambah node ke-3
docker-compose -f docker-compose.yml -f docker-compose.scale.yml up -d
```

### 7. Cleanup
```bash
docker-compose down -v
```

---

## Endpoint Reference

| Endpoint | Keterangan | Cache |
|----------|------------|-------|
| `GET /` | Info node, metrics | 30s |
| `GET /health` | Health check | No |
| `GET /cache-demo` | Demo Redis caching | No |
| `GET /static/asset` | Simulasi CDN asset | 5 min |
| `GET /no-cache` | Real-time data | No |
| `GET /load-test` | CPU benchmark | No |
| `GET /metrics` | Prometheus metrics | No |

---

## Struktur File

```
mini-cloud/
├── docker-compose.yml          # Orkestrasi utama
├── docker-compose.scale.yml    # Override untuk horizontal scaling
├── demo.sh                     # Script demo video
├── nginx/
│   ├── Dockerfile
│   ├── nginx.conf              # LB + caching config
│   └── nginx-scaled.conf       # Config setelah scaling
├── app1/                       # Worker Node 1
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── app2/                       # Worker Node 2 (sama)
├── app3/                       # Worker Node 3 (scale-out)
└── monitoring/
    └── prometheus.yml
```
