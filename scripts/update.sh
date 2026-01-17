#!/bin/bash
#
# Cardano Node Safe Update Script
# Safely upgrades cardano-node with backup and rollback support
#

set -e

# Configuration
DATA_DIR="${DATA_DIR:-/data/cardano}"
BACKUP_DIR="${BACKUP_DIR:-/data/cardano-backups}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
SERVICE_NAME="cardano-node"
DOWNLOAD_URL="https://github.com/IntersectMBO/cardano-node/releases/download"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Display usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <VERSION>

Safely upgrade cardano-node to a specified version.

Arguments:
    VERSION         Target version (e.g., 10.1.4)

Options:
    -h, --help      Show this help message
    -f, --force     Skip confirmation prompts
    -b, --backup    Only create backup, don't upgrade
    -r, --rollback  Rollback to previous version
    --skip-backup   Skip backup step (not recommended)
    --dry-run       Show what would be done without making changes

Examples:
    $(basename "$0") 10.1.4           # Upgrade to version 10.1.4
    $(basename "$0") -b               # Create backup only
    $(basename "$0") -r               # Rollback to previous version
EOF
    exit 0
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Get current installed version
get_current_version() {
    if command -v cardano-node &> /dev/null; then
        cardano-node --version | head -1 | awk '{print $2}'
    else
        echo "not-installed"
    fi
}

# Check if node is running
is_node_running() {
    systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

# Check disk space
check_disk_space() {
    local required_gb=5
    local available_gb=$(df -BG /tmp | tail -1 | awk '{print $4}' | tr -d 'G')
    
    if [[ $available_gb -lt $required_gb ]]; then
        log_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        exit 1
    fi
    log_info "Disk space check passed (${available_gb}GB available)"
}

# Create backup
create_backup() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating backup at ${backup_path}..."
    mkdir -p "$backup_path"
    
    # Backup binaries
    if [[ -f "${INSTALL_DIR}/cardano-node" ]]; then
        cp "${INSTALL_DIR}/cardano-node" "${backup_path}/"
        cp "${INSTALL_DIR}/cardano-cli" "${backup_path}/"
        log_info "Backed up binaries"
    fi
    
    # Backup configuration
    if [[ -d "${DATA_DIR}/config" ]]; then
        cp -r "${DATA_DIR}/config" "${backup_path}/"
        log_info "Backed up configuration"
    fi
    
    # Backup keys (if exist)
    if [[ -d "${DATA_DIR}/keys" ]]; then
        cp -r "${DATA_DIR}/keys" "${backup_path}/"
        log_info "Backed up keys"
    fi
    
    # Save current version
    get_current_version > "${backup_path}/version.txt"
    
    # Create symlink to latest backup
    ln -sfn "$backup_path" "${BACKUP_DIR}/latest"
    
    log_success "Backup created: ${backup_path}"
    echo "$backup_path"
}

# Download new version
download_version() {
    local version="$1"
    local download_file="cardano-node-${version}-linux.tar.gz"
    local download_path="/tmp/${download_file}"
    
    log_info "Downloading cardano-node version ${version}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would download from ${DOWNLOAD_URL}/${version}/${download_file}"
        return 0
    fi
    
    # Download
    if ! wget -q --show-progress -O "$download_path" "${DOWNLOAD_URL}/${version}/${download_file}"; then
        log_error "Failed to download version ${version}"
        log_info "Check available versions at: https://github.com/IntersectMBO/cardano-node/releases"
        exit 1
    fi
    
    log_success "Download complete: ${download_path}"
    echo "$download_path"
}

# Stop the node
stop_node() {
    if is_node_running; then
        log_info "Stopping cardano-node service..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would stop ${SERVICE_NAME}"
            return 0
        fi
        
        systemctl stop "$SERVICE_NAME"
        sleep 5
        
        if is_node_running; then
            log_error "Failed to stop cardano-node"
            exit 1
        fi
        log_success "Node stopped"
    else
        log_info "Node is not running"
    fi
}

# Start the node
start_node() {
    log_info "Starting cardano-node service..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would start ${SERVICE_NAME}"
        return 0
    fi
    
    systemctl start "$SERVICE_NAME"
    sleep 5
    
    if ! is_node_running; then
        log_error "Failed to start cardano-node"
        log_warn "Check logs: journalctl -u ${SERVICE_NAME} -n 50"
        exit 1
    fi
    log_success "Node started"
}

# Install new version
install_version() {
    local archive_path="$1"
    local temp_dir="/tmp/cardano-install-$$"
    
    log_info "Installing new version..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would extract and install binaries to ${INSTALL_DIR}"
        return 0
    fi
    
    mkdir -p "$temp_dir"
    tar -xzf "$archive_path" -C "$temp_dir"
    
    # Find and install binaries
    local node_bin=$(find "$temp_dir" -name "cardano-node" -type f | head -1)
    local cli_bin=$(find "$temp_dir" -name "cardano-cli" -type f | head -1)
    
    if [[ -z "$node_bin" ]] || [[ -z "$cli_bin" ]]; then
        log_error "Could not find binaries in archive"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    mv "$node_bin" "${INSTALL_DIR}/cardano-node"
    mv "$cli_bin" "${INSTALL_DIR}/cardano-cli"
    chmod +x "${INSTALL_DIR}/cardano-node" "${INSTALL_DIR}/cardano-cli"
    
    rm -rf "$temp_dir"
    log_success "Binaries installed to ${INSTALL_DIR}"
}

# Verify installation
verify_installation() {
    local expected_version="$1"
    
    log_info "Verifying installation..."
    
    local installed_version=$(get_current_version)
    
    if [[ "$installed_version" == *"$expected_version"* ]]; then
        log_success "Version verified: ${installed_version}"
    else
        log_warn "Version mismatch. Expected: ${expected_version}, Got: ${installed_version}"
    fi
    
    # Check node health after a few seconds
    if is_node_running; then
        sleep 10
        log_info "Checking sync status..."
        if command -v cardano-cli &> /dev/null; then
            cardano-cli query tip --mainnet 2>/dev/null || log_warn "Could not query tip (node may still be starting)"
        fi
    fi
}

# Rollback to previous version
rollback() {
    local latest_backup="${BACKUP_DIR}/latest"
    
    if [[ ! -d "$latest_backup" ]]; then
        log_error "No backup found to rollback to"
        exit 1
    fi
    
    log_warn "Rolling back to previous version..."
    
    stop_node
    
    if [[ -f "${latest_backup}/cardano-node" ]]; then
        cp "${latest_backup}/cardano-node" "${INSTALL_DIR}/"
        cp "${latest_backup}/cardano-cli" "${INSTALL_DIR}/"
        log_success "Binaries restored"
    fi
    
    if [[ -d "${latest_backup}/config" ]]; then
        cp -r "${latest_backup}/config/"* "${DATA_DIR}/config/"
        log_success "Configuration restored"
    fi
    
    start_node
    
    local restored_version=$(cat "${latest_backup}/version.txt" 2>/dev/null || echo "unknown")
    log_success "Rollback complete. Version: ${restored_version}"
}

# Main upgrade function
upgrade() {
    local version="$1"
    
    log_info "=========================================="
    log_info "Cardano Node Upgrade"
    log_info "=========================================="
    log_info "Target version: ${version}"
    log_info "Current version: $(get_current_version)"
    log_info "=========================================="
    
    # Confirmation
    if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        read -p "Continue with upgrade? (y/N): " confirm
        if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
            log_info "Upgrade cancelled"
            exit 0
        fi
    fi
    
    # Pre-flight checks
    check_disk_space
    
    # Backup
    if [[ "$SKIP_BACKUP" != "true" ]]; then
        create_backup
    else
        log_warn "Skipping backup (--skip-backup flag set)"
    fi
    
    # Download
    local archive_path=$(download_version "$version")
    
    # Stop node
    stop_node
    
    # Install
    install_version "$archive_path"
    
    # Start node
    start_node
    
    # Verify
    verify_installation "$version"
    
    # Cleanup
    rm -f "$archive_path"
    
    log_info "=========================================="
    log_success "Upgrade to version ${version} complete!"
    log_info "=========================================="
    log_info "Monitor logs: journalctl -u ${SERVICE_NAME} -f"
    log_info "Check sync: cardano-cli query tip --mainnet"
}

# Parse arguments
FORCE=false
BACKUP_ONLY=false
DO_ROLLBACK=false
SKIP_BACKUP=false
DRY_RUN=false
VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -b|--backup)
            BACKUP_ONLY=true
            shift
            ;;
        -r|--rollback)
            DO_ROLLBACK=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

# Main execution
check_permissions

if [[ "$BACKUP_ONLY" == "true" ]]; then
    create_backup
    exit 0
fi

if [[ "$DO_ROLLBACK" == "true" ]]; then
    rollback
    exit 0
fi

if [[ -z "$VERSION" ]]; then
    log_error "Version is required"
    usage
fi

upgrade "$VERSION"
