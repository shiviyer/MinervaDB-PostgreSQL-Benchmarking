#!/usr/bin/env bash
# =============================================================================
# MinervaDB PostgreSQL Benchmarking Toolkit
# install-dependencies.sh - Install all required benchmarking tools
# =============================================================================
# Version:     1.0.0
# Compatible:  Ubuntu 20.04+, RHEL/CentOS 8+, Debian 11+
# PostgreSQL:  15, 16, 17, 18
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/minervadb-install-$(date +%Y%m%d-%H%M%S).log"
HAMMERDB_VERSION="4.12"
HAMMERDB_DOWNLOAD_URL="https://github.com/TPC-Council/HammerDB/releases/download/v${HAMMERDB_VERSION}/HammerDB-${HAMMERDB_VERSION}-Linux.tar.gz"

# =============================================================================
# Utility Functions
# =============================================================================

log() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_FILE}"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"; exit 1; }

print_banner() {
    echo -e "${BOLD}"
    echo "============================================================="
    echo "  MinervaDB PostgreSQL Benchmarking Toolkit"
    echo "  Dependency Installer v1.0.0"
    echo "  https://minervadb.com"
    echo "============================================================="
    echo -e "${NC}"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
    else
        error "Unsupported operating system"
    fi
    log "Detected OS: ${OS} ${OS_VERSION}"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "This script is not running as root. Some installations may require sudo."
    fi
}

# =============================================================================
# Package Installation Functions
# =============================================================================

install_ubuntu_debian() {
    log "Installing dependencies for Ubuntu/Debian..."
    
    apt-get update -qq
    
    # Essential tools
    apt-get install -y \
        wget curl git build-essential \
        python3 python3-pip python3-venv \
        jq bc gawk \
        sysstat iostat dstat \
        htop iotop iftop \
        lsof netstat-nat \
        numactl hwloc \
        libaio-dev libssl-dev \
        2>&1 | tee -a "${LOG_FILE}"
    
    # PostgreSQL client tools (if not already installed)
    if ! command -v psql &>/dev/null; then
        log "Installing PostgreSQL client tools..."
        apt-get install -y postgresql-client 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    success "Ubuntu/Debian base packages installed"
}

install_rhel_centos() {
    log "Installing dependencies for RHEL/CentOS/AlmaLinux/Rocky..."
    
    # Enable EPEL
    if ! rpm -q epel-release &>/dev/null; then
        dnf install -y epel-release 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    dnf install -y \
        wget curl git gcc gcc-c++ make \
        python3 python3-pip \
        jq bc gawk \
        sysstat \
        htop iotop \
        lsof net-tools \
        numactl hwloc \
        libaio-devel openssl-devel \
        2>&1 | tee -a "${LOG_FILE}"
    
    success "RHEL/CentOS base packages installed"
}

install_pgbench() {
    log "Checking pgbench installation..."
    
    if command -v pgbench &>/dev/null; then
        PGBENCH_VER=$(pgbench --version 2>&1 | head -1)
        success "pgbench already installed: ${PGBENCH_VER}"
        return 0
    fi
    
    log "Installing pgbench..."
    case "${OS}" in
        ubuntu|debian)
            # Try multiple PostgreSQL versions
            for PG_VER in 18 17 16 15; do
                if apt-cache show postgresql-${PG_VER} &>/dev/null; then
                    apt-get install -y postgresql-${PG_VER} 2>&1 | tee -a "${LOG_FILE}"
                    break
                fi
            done
            ;;
        rhel|centos|almalinux|rocky)
            for PG_VER in 18 17 16 15; do
                if dnf list postgresql${PG_VER}-server &>/dev/null; then
                    dnf install -y postgresql${PG_VER} postgresql${PG_VER}-contrib 2>&1 | tee -a "${LOG_FILE}"
                    break
                fi
            done
            ;;
    esac
    
    success "pgbench installed"
}

install_sysbench() {
    log "Checking sysbench installation..."
    
    if command -v sysbench &>/dev/null; then
        SYSBENCH_VER=$(sysbench --version 2>&1 | head -1)
        success "sysbench already installed: ${SYSBENCH_VER}"
        return 0
    fi
    
    log "Installing sysbench..."
    case "${OS}" in
        ubuntu|debian)
            curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | bash
            apt-get install -y sysbench 2>&1 | tee -a "${LOG_FILE}"
            ;;
        rhel|centos|almalinux|rocky)
            curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.rpm.sh | bash
            dnf install -y sysbench 2>&1 | tee -a "${LOG_FILE}"
            ;;
    esac
    
    success "sysbench installed: $(sysbench --version)"
}

install_hammerdb() {
    log "Checking HammerDB installation..."
    
    if [ -d "/opt/HammerDB" ]; then
        success "HammerDB already installed at /opt/HammerDB"
        return 0
    fi
    
    log "Downloading HammerDB ${HAMMERDB_VERSION}..."
    
    # Install dependencies
    case "${OS}" in
        ubuntu|debian)
            apt-get install -y tcl tcllib 2>&1 | tee -a "${LOG_FILE}"
            ;;
        rhel|centos|almalinux|rocky)
            dnf install -y tcl tcllib 2>&1 | tee -a "${LOG_FILE}"
            ;;
    esac
    
    cd /tmp
    wget -q "${HAMMERDB_DOWNLOAD_URL}" -O "HammerDB-${HAMMERDB_VERSION}-Linux.tar.gz"
    tar -xzf "HammerDB-${HAMMERDB_VERSION}-Linux.tar.gz"
    mv "HammerDB-${HAMMERDB_VERSION}" /opt/HammerDB
    ln -sf /opt/HammerDB/hammerdb /usr/local/bin/hammerdb
    
    success "HammerDB ${HAMMERDB_VERSION} installed at /opt/HammerDB"
}

install_python_deps() {
    log "Installing Python dependencies for result analysis..."
    
    pip3 install --quiet \
        psycopg2-binary \
        pandas \
        matplotlib \
        seaborn \
        tabulate \
        rich \
        click \
        pyyaml \
        jinja2 \
        numpy \
        scipy 2>&1 | tee -a "${LOG_FILE}"
    
    success "Python dependencies installed"
}

install_monitoring_tools() {
    log "Installing monitoring and observability tools..."
    
    case "${OS}" in
        ubuntu|debian)
            apt-get install -y \
                prometheus-node-exporter \
                dstat \
                nicstat \
                2>&1 | tee -a "${LOG_FILE}" || true
            ;;
        rhel|centos|almalinux|rocky)
            dnf install -y \
                node_exporter \
                dstat \
                2>&1 | tee -a "${LOG_FILE}" || true
            ;;
    esac
    
    success "Monitoring tools installed"
}

verify_installations() {
    log "Verifying all installations..."
    echo ""
    echo -e "${BOLD}Installation Summary:${NC}"
    echo "------------------------------------------------------------"
    
    check_tool() {
        local tool=$1
        local cmd=$2
        if command -v "${cmd}" &>/dev/null; then
            local ver=$("${cmd}" --version 2>&1 | head -1 || echo "installed")
            echo -e "  ${GREEN}✓${NC} ${tool}: ${ver}"
        else
            echo -e "  ${RED}✗${NC} ${tool}: NOT FOUND"
        fi
    }
    
    check_tool "pgbench" "pgbench"
    check_tool "sysbench" "sysbench"
    check_tool "psql" "psql"
    check_tool "python3" "python3"
    check_tool "git" "git"
    check_tool "jq" "jq"
    
    [ -f "/usr/local/bin/hammerdb" ] && \
        echo -e "  ${GREEN}✓${NC} HammerDB: v${HAMMERDB_VERSION}" || \
        echo -e "  ${RED}✗${NC} HammerDB: NOT FOUND"
    
    echo "------------------------------------------------------------"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_banner
    
    log "Installation log: ${LOG_FILE}"
    
    check_root
    detect_os
    
    case "${OS}" in
        ubuntu|debian)       install_ubuntu_debian ;;
        rhel|centos|almalinux|rocky|fedora) install_rhel_centos ;;
        *)  error "Unsupported OS: ${OS}" ;;
    esac
    
    install_pgbench
    install_sysbench
    install_hammerdb
    install_python_deps
    install_monitoring_tools
    verify_installations
    
    success "All dependencies installed successfully!"
    log "Next step: Run 'bash 00-prerequisites/environment-validation.sh' to validate your environment"
}

main "$@"
