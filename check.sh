#!/usr/bin/env bash
# check.sh — Pre-flight check for the vsl2 Vagrant environment.
# Verifies tools, host configuration, local boxes, and port availability.
# Supports macOS, Linux, and Windows (Git Bash).
# Usage: ./check.sh

set -uo pipefail

# ── Expected Versions ─────────────────────────────────────────────────────────
# This environment was built and validated against these specific versions.
# Other versions may work but have not been tested.

EXP_VBX="7.1"           # VirtualBox major.minor
EXP_VGR="2.4"           # Vagrant major.minor
EXP_HM="1.8.10"         # vagrant-hostmanager
EXP_VBG="0.32.0"        # vagrant-vbguest

# ── OS Detection ──────────────────────────────────────────────────────────────

case "$(uname -s)" in
    Darwin)               OS_TYPE="macos"   ;;
    Linux)                OS_TYPE="linux"   ;;
    MINGW*|MSYS*|CYGWIN*) OS_TYPE="windows" ;;
    *)                    OS_TYPE="unknown" ;;
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

# Returns major.minor from a version string (e.g. "7.1.10" -> "7.1")
major_minor() { echo "$1" | cut -d. -f1,2; }

port_in_use() {
    local port="$1"
    case "$OS_TYPE" in
        macos)
            lsof -iTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null | grep "127.0.0.1:$port" > /dev/null
            ;;
        linux)
            if cmd_exists lsof; then
                lsof -iTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null | grep "127.0.0.1:$port" > /dev/null
            elif cmd_exists ss; then
                ss -tlnp 2>/dev/null | grep "127.0.0.1:$port" > /dev/null
            else
                netstat -tlnp 2>/dev/null | grep "127.0.0.1:$port" > /dev/null
            fi
            ;;
        windows)
            netstat -an 2>/dev/null | grep "127.0.0.1:$port" > /dev/null
            ;;
    esac
}

# ── Header ────────────────────────────────────────────────────────────────────

echo -e "${BLD}vsl2 — Environment Pre-flight Check${RST}"
echo -e "Platform : $OS_TYPE"
echo -e "Expected : VirtualBox $EXP_VBX.x  |  Vagrant $EXP_VGR.x  |  vagrant-hostmanager $EXP_HM  |  vagrant-vbguest $EXP_VBG"

# ── Tools ─────────────────────────────────────────────────────────────────────

section "Tools"

# Kernel headers and modules (Linux only — required for VirtualBox to function)
if [[ "$OS_TYPE" == "linux" ]]; then
    KVER=$(uname -r)
    if [[ -d "/usr/src/linux-headers-${KVER}" ]]; then
        pass "Kernel headers ($KVER)"
    else
        fail "Kernel headers not installed ($KVER) — run: sudo apt-get install -y linux-headers-amd64 linux-headers-${KVER}"
    fi
fi

# VirtualBox
VBX_FOUND=0
if cmd_exists VBoxManage; then
    VBX_VER=$(VBoxManage --version 2>/dev/null | sed 's/r.*//')
    VBX_MM=$(major_minor "$VBX_VER")
    if [[ "$VBX_MM" == "$EXP_VBX" ]]; then
        pass "VirtualBox $VBX_VER"
    else
        warn "VirtualBox $VBX_VER — expected $EXP_VBX.x — other versions may work but are untested"
    fi
    VBX_FOUND=1
    # Verify kernel modules compiled and loaded (Linux only)
    if [[ "$OS_TYPE" == "linux" ]]; then
        if lsmod 2>/dev/null | grep vboxdrv > /dev/null; then
            pass "VirtualBox kernel modules loaded"
        else
            fail "VirtualBox kernel modules not loaded — run: sudo /sbin/vboxconfig"
        fi
    fi
else
    fail "VirtualBox not found — install $EXP_VBX.x from https://virtualbox.org"
fi

# Extension Pack
if [[ $VBX_FOUND -eq 1 ]]; then
    EXT_INFO=$(VBoxManage list extpacks 2>/dev/null)
    if echo "$EXT_INFO" | grep -q "Oracle VirtualBox Extension Pack"; then
        EXT_VER=$(echo "$EXT_INFO" | grep "^Version:" | awk '{print $2}' | head -1)
        EXT_MM=$(major_minor "${EXT_VER%%r*}")
        VBX_MM_CLEAN=$(major_minor "${VBX_VER%%r*}")
        if [[ "$EXT_MM" == "$VBX_MM_CLEAN" ]]; then
            pass "Extension Pack $EXT_VER (matches VirtualBox)"
        else
            warn "Extension Pack $EXT_VER does not match VirtualBox $VBX_VER — versions must match exactly"
        fi
    else
        fail "VirtualBox Extension Pack not installed — must match VirtualBox $VBX_VER exactly"
    fi
fi

# Vagrant
VGR_FOUND=0
if cmd_exists vagrant; then
    VGR_VER=$(vagrant --version 2>/dev/null | awk '{print $2}')
    VGR_MM=$(major_minor "$VGR_VER")
    if [[ "$VGR_MM" == "$EXP_VGR" ]]; then
        pass "Vagrant $VGR_VER"
    else
        warn "Vagrant $VGR_VER — expected $EXP_VGR.x — other versions may work but are untested"
    fi
    VGR_FOUND=1
else
    fail "Vagrant not found — install $EXP_VGR.x from https://developer.hashicorp.com/vagrant/install"
fi

# Vagrant plugins
if [[ $VGR_FOUND -eq 1 ]]; then
    PLUGINS=$(vagrant plugin list 2>/dev/null)

    if echo "$PLUGINS" | grep -q "vagrant-hostmanager"; then
        HM_VER=$(echo "$PLUGINS" | grep "vagrant-hostmanager" | awk '{print $2}' | tr -d '(),')
        if [[ "$HM_VER" == "$EXP_HM" ]]; then
            pass "vagrant-hostmanager $HM_VER"
        else
            warn "vagrant-hostmanager $HM_VER — expected $EXP_HM — other versions may work but are untested"
        fi
    else
        fail "vagrant-hostmanager not installed — run: vagrant plugin install vagrant-hostmanager --plugin-version $EXP_HM"
    fi

    if echo "$PLUGINS" | grep -q "vagrant-vbguest"; then
        VBG_VER=$(echo "$PLUGINS" | grep "vagrant-vbguest" | awk '{print $2}' | tr -d '(),')
        if [[ "$VBG_VER" == "$EXP_VBG" ]]; then
            pass "vagrant-vbguest $VBG_VER"
        else
            warn "vagrant-vbguest $VBG_VER — expected $EXP_VBG — other versions may work but are untested"
        fi
    else
        fail "vagrant-vbguest not installed — run: vagrant plugin install vagrant-vbguest --plugin-version $EXP_VBG"
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
    # VirtualBox 7.x uses hostonlynets (new-style); fall back to hostonlyifs for older installs
    HO_INFO=$(VBoxManage list hostonlynets 2>/dev/null)
    HO_IP_FIELD="LowerIP:"
    if [[ -z "$HO_INFO" ]]; then
        HO_INFO=$(VBoxManage list hostonlyifs 2>/dev/null)
        HO_IP_FIELD="IPAddress:"
    fi

    case "$OS_TYPE" in
        macos|linux)
            ADAPTER_NAME="vboxnet1"
            ADAPTER_LABEL="vboxnet1"
            ;;
        windows)
            ADAPTER_NAME="VirtualBox Host-Only Ethernet Adapter #2"
            ADAPTER_LABEL="VirtualBox Host-Only Ethernet Adapter #2"
            ;;
    esac

    if echo "$HO_INFO" | grep -q "Name:.*${ADAPTER_NAME}"; then
        HO_IP=$(echo "$HO_INFO" | awk "/^Name:/{found=0} /Name:.*${ADAPTER_NAME}/{found=1} found && /${HO_IP_FIELD}/{print \$2; exit}")
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
    if VBoxManage list natnetworks 2>/dev/null | grep "VSL_Network" > /dev/null; then
        pass "VSL_Network NAT network exists"
    else
        fail "VSL_Network not found — create it in VirtualBox: File → Tools → Network Manager → NAT Networks"
    fi
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
