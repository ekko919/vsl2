#!/usr/bin/env bash
# check.sh — Pre-flight check for the vsl2 Vagrant environment.
# Verifies tools, host configuration, local boxes, and port availability.
# Supports macOS, Linux, and Windows (Git Bash).
# Usage: ./check.sh

set -uo pipefail

# ── OS Detection ──────────────────────────────────────────────────────────────

case "$(uname -s)" in
    Darwin)         OS_TYPE="macos"   ;;
    Linux)          OS_TYPE="linux"   ;;
    MINGW*|MSYS*|CYGWIN*) OS_TYPE="windows" ;;
    *)              OS_TYPE="unknown" ;;
esac

# ── Formatting ────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YEL='\033[0;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
BLD='\033[1m'
RST='\033[0m'

PASS=0
WARN=0
FAIL=0

pass()    { echo -e "  ${GRN}[PASS]${RST} $1"; PASS=$((PASS + 1)); }
warn()    { echo -e "  ${YEL}[WARN]${RST} $1"; WARN=$((WARN + 1)); }
fail()    { echo -e "  ${RED}[FAIL]${RST} $1"; FAIL=$((FAIL + 1)); }
section() { echo -e "\n${BLD}${CYN}── $1 ${RST}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

cmd_exists() { command -v "$1" &>/dev/null; }

port_in_use() {
    local port="$1"
    case "$OS_TYPE" in
        macos)
            lsof -iTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null | grep -q "127.0.0.1:$port"
            ;;
        linux)
            if cmd_exists lsof; then
                lsof -iTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null | grep -q "127.0.0.1:$port"
            elif cmd_exists ss; then
                ss -tlnp 2>/dev/null | grep -q "127.0.0.1:$port"
            else
                netstat -tlnp 2>/dev/null | grep -q "127.0.0.1:$port"
            fi
            ;;
        windows)
            netstat -an 2>/dev/null | grep -q "127.0.0.1:$port"
            ;;
    esac
}

# ── Header ────────────────────────────────────────────────────────────────────

echo -e "${BLD}vsl2 — Environment Pre-flight Check${RST}"
echo -e "Platform: $OS_TYPE"

# ── Tools ─────────────────────────────────────────────────────────────────────

section "Tools"

# VirtualBox
if cmd_exists VBoxManage; then
    VBX_VER=$(VBoxManage --version 2>/dev/null | sed 's/r.*//')
    VBX_MAJ=$(echo "$VBX_VER" | cut -d. -f1)
    if [[ "$VBX_MAJ" == "7" ]]; then
        pass "VirtualBox $VBX_VER"
    else
        warn "VirtualBox $VBX_VER (expected 7.1.x)"
    fi
    VBX_FOUND=1
else
    fail "VirtualBox not found — install from https://virtualbox.org"
    VBX_FOUND=0
fi

# Extension Pack
if [[ $VBX_FOUND -eq 1 ]]; then
    EXT_INFO=$(VBoxManage list extpacks 2>/dev/null)
    if echo "$EXT_INFO" | grep -q "Oracle VirtualBox Extension Pack"; then
        EXT_VER=$(echo "$EXT_INFO" | grep "^Version:" | awk '{print $2}' | head -1)
        if [[ "${EXT_VER%%r*}" == "${VBX_VER%%r*}" ]]; then
            pass "Extension Pack $EXT_VER (matches VirtualBox)"
        else
            warn "Extension Pack $EXT_VER does not match VirtualBox $VBX_VER — versions must match"
        fi
    else
        fail "VirtualBox Extension Pack not installed"
    fi
fi

# Vagrant
if cmd_exists vagrant; then
    VGR_VER=$(vagrant --version 2>/dev/null | awk '{print $2}')
    VGR_MAJ=$(echo "$VGR_VER" | cut -d. -f1)
    VGR_MIN=$(echo "$VGR_VER" | cut -d. -f2)
    if [[ "$VGR_MAJ" == "2" && "$VGR_MIN" == "4" ]]; then
        pass "Vagrant $VGR_VER"
    else
        warn "Vagrant $VGR_VER (expected 2.4.x)"
    fi
    VGR_FOUND=1
else
    fail "Vagrant not found — install from https://developer.hashicorp.com/vagrant/install"
    VGR_FOUND=0
fi

# Vagrant plugins
if [[ $VGR_FOUND -eq 1 ]]; then
    PLUGINS=$(vagrant plugin list 2>/dev/null)
    if echo "$PLUGINS" | grep -q "vagrant-hostmanager"; then
        HM_VER=$(echo "$PLUGINS" | grep "vagrant-hostmanager" | awk '{print $2}' | tr -d '(),')
        pass "vagrant-hostmanager $HM_VER"
    else
        fail "vagrant-hostmanager not installed — run: vagrant plugin install vagrant-hostmanager"
    fi

    if echo "$PLUGINS" | grep -q "vagrant-vbguest"; then
        VBG_VER=$(echo "$PLUGINS" | grep "vagrant-vbguest" | awk '{print $2}' | tr -d '(),')
        pass "vagrant-vbguest $VBG_VER"
    else
        fail "vagrant-vbguest not installed — run: vagrant plugin install vagrant-vbguest"
    fi
fi

# ── Host Configuration ────────────────────────────────────────────────────────

section "Host Configuration"

# /etc/vbox/networks.conf (macOS and Linux only — not used on Windows)
if [[ "$OS_TYPE" != "windows" ]]; then
    NETS_CONF="/etc/vbox/networks.conf"
    if [[ -f "$NETS_CONF" ]]; then
        if grep -q "0\.0\.0\.0/0" "$NETS_CONF"; then
            pass "$NETS_CONF — unrestricted host-only ranges allowed"
        else
            warn "$NETS_CONF exists but does not contain '0.0.0.0/0' — VirtualBox may block the 172.16.100.0/24 range"
        fi
    else
        fail "$NETS_CONF not found — create it with: echo '* 0.0.0.0/0 ::/0' | sudo tee $NETS_CONF"
    fi
fi

# Host-only adapter — name differs by OS
if [[ $VBX_FOUND -eq 1 ]]; then
    HO_INFO=$(VBoxManage list hostonlyifs 2>/dev/null)

    case "$OS_TYPE" in
        macos|linux)
            ADAPTER_NAME="vboxnet1"
            ADAPTER_LABEL="vboxnet1"
            ;;
        windows)
            # Windows names host-only adapters as "VirtualBox Host-Only Ethernet Adapter #2"
            ADAPTER_NAME="VirtualBox Host-Only Ethernet Adapter #2"
            ADAPTER_LABEL="VirtualBox Host-Only Ethernet Adapter #2"
            ;;
    esac

    if echo "$HO_INFO" | grep -q "Name:.*${ADAPTER_NAME}"; then
        HO_IP=$(echo "$HO_INFO" | awk "/Name:.*${ADAPTER_NAME}/{found=1} found && /IPAddress:/{print \$2; exit}")
        if [[ "$HO_IP" == "172.16.100.1" ]]; then
            pass "$ADAPTER_LABEL — IP $HO_IP"
        else
            warn "$ADAPTER_LABEL found but IP is $HO_IP (expected 172.16.100.1)"
        fi
    else
        fail "$ADAPTER_LABEL not found — create it in VirtualBox: File → Host Network Manager"
    fi
fi

# VSL_Network NAT network
if [[ $VBX_FOUND -eq 1 ]]; then
    if VBoxManage list natnetworks 2>/dev/null | grep -q "VSL_Network"; then
        pass "VSL_Network NAT network exists"
    else
        fail "VSL_Network not found — create it in VirtualBox: File → Tools → Network Manager → NAT Networks"
    fi
fi

# ── Local Vagrant Boxes ───────────────────────────────────────────────────────

section "Local Vagrant Boxes"

if [[ $VGR_FOUND -eq 1 ]]; then
    BOX_LIST=$(vagrant box list 2>/dev/null)
    for BOX in ALMA-8 ROCKY-8 ROCKY-9 ORACLE-8 DEBIAN-11 DEBIAN-12; do
        if echo "$BOX_LIST" | grep -q "^$BOX "; then
            BOX_VER=$(echo "$BOX_LIST" | grep "^$BOX " | awk -F'[()]' '{print $2}' | head -1)
            pass "$BOX ($BOX_VER)"
        else
            fail "$BOX not registered — build with auto.packer and register locally"
        fi
    done
fi

# ── Port Availability ─────────────────────────────────────────────────────────

section "Port Availability (127.0.0.1)"

PORTS=(2211 2212 2213 2214 2215 2216 2217 2218 2219 2298 2299)
PORT_FAIL=0
for PORT in "${PORTS[@]}"; do
    if port_in_use "$PORT"; then
        fail "Port $PORT already in use"
        PORT_FAIL=$((PORT_FAIL + 1))
    fi
done
if [[ $PORT_FAIL -eq 0 ]]; then
    pass "All forwarded ports (2211-2219, 2298-2299) are free"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo -e "\n${BLD}── Summary ${RST}"
echo -e "  ${GRN}PASS${RST}  $PASS"
[[ $WARN -gt 0 ]] && echo -e "  ${YEL}WARN${RST}  $WARN"
[[ $FAIL -gt 0 ]] && echo -e "  ${RED}FAIL${RST}  $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo -e "\n  ${RED}Environment is not ready.${RST} Resolve FAIL items before running 'vagrant up'."
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "\n  ${YEL}Environment may work but has warnings.${RST} Review WARN items before running 'vagrant up'."
    exit 0
else
    echo -e "\n  ${GRN}Environment looks good.${RST} Run 'vagrant up' to start."
    exit 0
fi
