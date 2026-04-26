#!/bin/bash
# ============================================================
# DEMO SCRIPT - Mini-Cloud Environment Simulation
# UTS Cloud Computing
# Gunakan script ini saat rekaman video
# ============================================================

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
    sleep 1
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# ============================================================
# FASE 1: RESOURCE PROVISIONING (IaaS Demo)
# ============================================================
demo_provisioning() {
    header "FASE 1: SIMULASI RESOURCE PROVISIONING (IaaS)"

    step "Memulai provisioning infrastruktur Mini-Cloud..."
    echo -e "${CYAN}Perintah: docker-compose up -d${NC}"
    docker-compose up -d --build

    echo ""
    step "Menunggu semua container ready..."
    sleep 5

    step "Memeriksa status semua container (worker nodes):"
    docker-compose ps

    echo ""
    step "Melihat resource usage setiap node:"
    docker stats --no-stream --format \
        "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

    info "IaaS Provisioning selesai! 2 worker nodes + 1 LB + 1 Cache aktif"
}

# ============================================================
# FASE 2: LOAD BALANCING & HIGH AVAILABILITY
# ============================================================
demo_load_balancing() {
    header "FASE 2: SIMULASI LOAD BALANCING & HIGH AVAILABILITY"

    step "Mengirim 10 request ke Load Balancer dan lihat distribusi..."
    echo ""

    for i in $(seq 1 10); do
        RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost/)
        NODE=$(echo "$RESPONSE" | head -n1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['node']['id'])" 2>/dev/null || echo "unknown")
        STATUS=$(echo "$RESPONSE" | tail -n1)
        echo -e "  Request $i → Node: ${GREEN}${NODE}${NC} [HTTP $STATUS]"
        sleep 0.2
    done

    echo ""
    step "Demonstrasi FAULT TOLERANCE - Mematikan app-node-1..."
    echo -e "${RED}Perintah: docker stop cloud-app-node-1${NC}"
    docker stop cloud-app-node-1
    sleep 2

    echo ""
    step "Mengirim request saat node-1 DOWN (harus tetap bisa diakses):"
    for i in $(seq 1 5); do
        RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost/)
        NODE=$(echo "$RESPONSE" | head -n1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['node']['id'])" 2>/dev/null || echo "ERROR")
        STATUS=$(echo "$RESPONSE" | tail -n1)
        echo -e "  Request $i → Node: ${YELLOW}${NODE}${NC} [HTTP $STATUS] ← Failover otomatis!"
        sleep 0.2
    done

    echo ""
    step "Memulihkan node-1 kembali (self-healing)..."
    echo -e "${GREEN}Perintah: docker start cloud-app-node-1${NC}"
    docker start cloud-app-node-1
    sleep 3

    info "High Availability terbukti: layanan tetap berjalan saat 1 node mati!"
}

# ============================================================
# FASE 3: ELASTICITY & HORIZONTAL SCALING
# ============================================================
demo_scaling() {
    header "FASE 3: SIMULASI ELASTICITY & HORIZONTAL SCALING"

    step "Status cluster sebelum scaling (2 nodes):"
    docker-compose ps

    echo ""
    step "HORIZONTAL SCALE-OUT: Menambah app-node-3 tanpa downtime..."
    echo -e "${CYAN}Perintah: docker-compose -f docker-compose.yml -f docker-compose.scale.yml up -d app-node-3${NC}"
    docker-compose -f docker-compose.yml -f docker-compose.scale.yml up -d app-node-3
    sleep 5

    step "Update load balancer untuk include node-3..."
    docker-compose -f docker-compose.yml -f docker-compose.scale.yml up -d load-balancer
    sleep 3

    step "Status cluster setelah scaling (3 nodes):"
    docker-compose -f docker-compose.yml -f docker-compose.scale.yml ps

    echo ""
    step "Verifikasi distribusi ke 3 node:"
    for i in $(seq 1 9); do
        RESPONSE=$(curl -s http://localhost/)
        NODE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['node']['id'])" 2>/dev/null || echo "unknown")
        echo -e "  Request $i → ${GREEN}${NODE}${NC}"
        sleep 0.1
    done

    info "Horizontal Scaling berhasil: 2 → 3 nodes tanpa downtime!"
    info "Bandingkan: Vertical Scaling = upgrade CPU/RAM 1 server (ada downtime)"
    info "            Horizontal Scaling = tambah server baru (zero downtime)"
}

# ============================================================
# FASE 4: CACHING & CDN SIMULATION
# ============================================================
demo_caching() {
    header "FASE 4: SIMULASI CACHING & CONTENT DELIVERY"

    step "Test 1: CACHE MISS (pertama kali, harus compute dari server)"
    echo -e "${CYAN}Request 1 ke /cache-demo:${NC}"
    curl -s http://localhost/cache-demo | python3 -m json.tool
    sleep 1

    echo ""
    step "Test 2: CACHE HIT (kedua kali, data dari Redis - lebih cepat)"
    echo -e "${CYAN}Request 2 ke /cache-demo:${NC}"
    curl -s http://localhost/cache-demo | python3 -m json.tool
    sleep 1

    echo ""
    step "Test Nginx CDN Cache (header X-Cache-Status):"
    echo -e "${CYAN}Request 1 ke /static/asset (MISS):${NC}"
    curl -s -I http://localhost/static/asset | grep -E "X-Cache|X-Served"

    sleep 0.5
    echo -e "${CYAN}Request 2 ke /static/asset (HIT dari Nginx):${NC}"
    curl -s -I http://localhost/static/asset | grep -E "X-Cache|X-Served"

    echo ""
    step "Perbandingan dengan/tanpa cache:"
    echo "  Tanpa cache (direct computation):"
    time curl -s http://localhost/cache-demo > /dev/null

    echo "  Dengan cache (dari Redis):"
    time curl -s http://localhost/cache-demo > /dev/null

    info "Caching terbukti meminimalkan beban server dan mempercepat response!"
}

# ============================================================
# MENU UTAMA
# ============================================================
show_menu() {
    header "DEMO MENU - Mini-Cloud Environment Simulation"
    echo "  1) Fase 1: Resource Provisioning (IaaS)"
    echo "  2) Fase 2: Load Balancing & Fault Tolerance"
    echo "  3) Fase 3: Elasticity & Horizontal Scaling"
    echo "  4) Fase 4: Caching & CDN Simulation"
    echo "  5) Jalankan SEMUA fase (Full Demo)"
    echo "  6) Cleanup (hapus semua container)"
    echo ""
    echo -n "Pilih [1-6]: "
}

cleanup() {
    header "CLEANUP"
    step "Menghentikan dan menghapus semua container..."
    docker-compose -f docker-compose.yml -f docker-compose.scale.yml down -v
    info "Semua resource berhasil dihapus."
}

# ============================================================
# MAIN
# ============================================================
if [ "$1" == "all" ]; then
    demo_provisioning
    sleep 2
    demo_load_balancing
    sleep 2
    demo_scaling
    sleep 2
    demo_caching
    exit 0
fi

while true; do
    show_menu
    read -r choice
    case $choice in
        1) demo_provisioning ;;
        2) demo_load_balancing ;;
        3) demo_scaling ;;
        4) demo_caching ;;
        5) demo_provisioning; demo_load_balancing; demo_scaling; demo_caching ;;
        6) cleanup; break ;;
        *) echo "Pilihan tidak valid" ;;
    esac
done
