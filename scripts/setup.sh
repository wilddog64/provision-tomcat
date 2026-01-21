#!/usr/bin/env bash
#
# Setup script for provision-tomcat role development environment
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_command() {
    if command -v "$1" &> /dev/null; then
        log_info "$1 is installed: $(command -v "$1")"
        return 0
    else
        log_warn "$1 is not installed"
        return 1
    fi
}

install_ansible_collections() {
    log_info "Installing Ansible collections..."
    ansible-galaxy collection install ansible.windows chocolatey.chocolatey -p ./collections --force
}

install_python_deps() {
    log_info "Installing Python dependencies..."
    if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
        pip install -r "$PROJECT_DIR/requirements.txt"
    fi
    pip install ansible-lint
}

install_ruby_deps() {
    log_info "Installing Ruby dependencies (for Test Kitchen)..."
    if [[ -f "$PROJECT_DIR/Gemfile" ]]; then
        cd "$PROJECT_DIR"
        if command -v rbenv &> /dev/null; then
             log_info "Using rbenv..."
             # Ensure bundler is installed in the current ruby version
             if ! rbenv exec command -v bundle &> /dev/null; then
                 log_info "Installing bundler..."
                 rbenv exec gem install bundler
             fi
             rbenv exec bundle install
        else
             bundle install
        fi
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    local missing=0

    check_command "direnv" || ((missing++))
    check_command "pyenv" || ((missing++))
    check_command "rbenv" || ((missing++))
    check_command "vagrant" || ((missing++))
    check_command "VBoxManage" || ((missing++))

    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        log_warn "Not inside a virtual environment. Is direnv loaded? (run 'direnv allow')"
        ((missing++))
    fi

    if [[ $missing -gt 0 ]]; then
        log_warn "Some prerequisites are missing or environment is not loaded."
    else
        log_info "All prerequisites are installed."
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [COMMAND]

Commands:
    check       Check if all prerequisites are installed
    deps        Install all dependencies (Ansible collections, Python, Ruby)
    ansible     Install Ansible collections only
    python      Install Python dependencies only
    ruby        Install Ruby/Kitchen dependencies only
    all         Run all setup steps
    help        Show this help message

Examples:
    $(basename "$0") check    # Check prerequisites
    $(basename "$0") deps     # Install all dependencies
    $(basename "$0") all      # Full setup
EOF
}

main() {
    local cmd="${1:-help}"

    case "$cmd" in
        check)
            check_prerequisites
            ;;
        deps)
            install_ansible_collections
            install_python_deps
            install_ruby_deps
            ;;
        ansible)
            install_ansible_collections
            ;;
        python)
            install_python_deps
            ;;
        ruby)
            install_ruby_deps
            ;;
        all)
            check_prerequisites
            install_ansible_collections
            install_python_deps
            install_ruby_deps
            log_info "Setup complete!"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
