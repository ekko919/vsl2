#!/usr/bin/env bash
# setup.sh — Installation guide for vsl2 prerequisites.
# Detects missing or misconfigured components and prints the exact commands
# needed to fix them. Nothing is installed or changed automatically.
# Supports macOS (Homebrew) and Linux (Debian/Ubuntu, RHEL/Rocky/Alma/Oracle).
# Usage: ./setup.sh

set -uo pipefail

# ── Expected Versions ─────────────────────────────────────────────────────────
EXP_VBX="7.1"
EXP_VGR="2.4"
EXP_HM="1.8.10"
EXP_VBG="0.32.0"

# ── OS / Distro Detection ─────────────────────────────────────────────────────
case "$(uname -s)" in
    Darwin)               OS_TYPE="macos"   ;;
    Linux)                OS_TYPE="linux"   ;;
    MINGW*|MSYS*|CYGWIN*) OS_TYPE="windows" ;;
    *)                    OS_TYPE="unknown" ;;
esac

LINUX_FLAVOR="unknown"
LINUX_CODENAME="unknown"
if [[ "$OS_TYPE" == "linux" && -f /etc/os-release ]]; then
    . /etc/os-release
    LINUX_CODENAME="${VERSION_CODENAME:-unknown}"
    case "${ID_LIKE:-${ID:-}}" in
        *debian*|*ubuntu*) LINUX_FLAVOR="debian" ;;
        *rhel*|*centos*|*fedora*) LINUX_FLAVOR="rhel" ;;
        *suse*) LINUX_FLAVOR="suse" ;;
    esac
fi

# ── Formatting ────────────────────────────────────────────────────────────────
YEL='\033[0;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
BLD='\033[1m'
RST='\033[0m'

ACTIONS=0

cmd_exists()  { command -v "$1" &>/dev/null; }
major_minor() { echo "$1" | cut -d. -f1,2; }
section()     { echo -e "\n${BLD}${CYN}── $1${RST}"; }
ok()          { echo -e "  ${GRN}[OK]${RST}   $1"; }
need()        { echo -e "\n  ${YEL}[NEED]${RST} $1"; ACTIONS=$((ACTIONS + 1)); }
cmd()         { printf '         \033[0;36m%s\033[0m\n' "$1"; }
note()        { echo -e "         ${YEL}# $1${RST}"; }

# ── Header ────────────────────────────────────────────────────────────────────
echo -e "${BLD}vsl2 — Environment Setup Guide${RST}"
if [[ "$OS_TYPE" == "linux" ]]; then
    echo -e "Platform : $OS_TYPE ($LINUX_FLAVOR)"
else
    echo -e "Platform : $OS_TYPE"
fi
echo -e "Expected : VirtualBox $EXP_VBX.x  |  Vagrant $EXP_VGR.x  |  vagrant-hostmanager $EXP_HM  |  vagrant-vbguest $EXP_VBG"

# ── Unsupported Platforms ─────────────────────────────────────────────────────
if [[ "$OS_TYPE" == "windows" ]]; then
    echo -e "\n${YEL}Windows install automation is not supported by this script.${RST}"
    echo -e "Install VirtualBox $EXP_VBX.x, Vagrant $EXP_VGR.x, and plugins manually — see README.md."
    exit 0
fi

if [[ "$OS_TYPE" == "unknown" ]]; then
    echo -e "\n${YEL}Unsupported platform — this script supports macOS and Linux only.${RST}"
    exit 1
fi

if [[ "$OS_TYPE" == "linux" && "$LINUX_FLAVOR" == "unknown" ]]; then
    echo -e "\n${YEL}Unrecognised Linux distribution. Commands shown below are for Debian/Ubuntu.${RST}"
    LINUX_FLAVOR="debian"
fi

# ── Extension Pack install commands (shared helper) ───────────────────────────
ext_pack_cmds() {
    case "$OS_TYPE" in
        macos)
            cmd "brew install --cask virtualbox-extension-pack"
            note "Homebrew installs the pack version that matches its VirtualBox cask"
            ;;
        linux)
            note "downloads the pack version that matches your installed VirtualBox:"
            cmd 'EXT_VER=$(VBoxManage --version | sed "s/r.*//")'
            cmd 'wget "https://download.virtualbox.org/virtualbox/${EXT_VER}/Oracle_VirtualBox_Extension_Pack-${EXT_VER}.vbox-extpack" \'
            cmd '     -O /tmp/extpack.vbox-extpack'
            cmd 'sudo VBoxManage extpack install --replace /tmp/extpack.vbox-extpack'
            cmd 'rm /tmp/extpack.vbox-extpack'
            ;;
    esac
}

# ── Tools ─────────────────────────────────────────────────────────────────────
section "Tools"

# Homebrew (macOS only)
if [[ "$OS_TYPE" == "macos" ]]; then
    if cmd_exists brew; then
        BREW_VER=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
        ok "Homebrew $BREW_VER"
    else
        need "Homebrew not installed — required for all cask installs"
        cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    fi
fi

# VirtualBox
VBX_FOUND=0
VBX_VER=""
if cmd_exists VBoxManage; then
    VBX_VER=$(VBoxManage --version 2>/dev/null | sed 's/r.*//')
    VBX_MM=$(major_minor "$VBX_VER")
    if [[ "$VBX_MM" == "$EXP_VBX" ]]; then
        ok "VirtualBox $VBX_VER"
    else
        need "VirtualBox $VBX_VER — expected $EXP_VBX.x"
        case "$OS_TYPE" in
            macos)
                note "remove current version first, then install pinned version:"
                cmd "brew uninstall --cask virtualbox-extension-pack virtualbox"
                cmd "brew install --cask virtualbox"
                note "if Homebrew cask is not $EXP_VBX.x, download directly: virtualbox.org/wiki/Downloads"
                ;;
            linux)
                note "remove current version and reinstall the pinned version — see commands below"
                ;;
        esac
    fi
    VBX_FOUND=1
else
    need "VirtualBox not installed"
    case "$OS_TYPE" in
        macos)
            cmd "brew install --cask virtualbox"
            note "if Homebrew cask is not $EXP_VBX.x, download directly: virtualbox.org/wiki/Downloads"
            ;;
        linux)
            case "$LINUX_FLAVOR" in
                debian)
                    cmd "wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc \\"
                    cmd "    | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg"
                    cmd "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] \\"
                    cmd "    https://download.virtualbox.org/virtualbox/debian $LINUX_CODENAME contrib\" \\"
                    cmd "    | sudo tee /etc/apt/sources.list.d/virtualbox.list"
                    cmd "sudo apt-get update"
                    cmd "sudo apt-get install -y virtualbox-${EXP_VBX}"
                    ;;
                rhel)
                    cmd "sudo dnf install -y kernel-devel kernel-headers gcc make perl"
                    cmd "sudo wget https://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo \\"
                    cmd "    -O /etc/yum.repos.d/virtualbox.repo"
                    cmd "sudo dnf install -y VirtualBox-${EXP_VBX}"
                    ;;
            esac
            ;;
    esac
fi

# Extension Pack
EXT_OK=0
if [[ $VBX_FOUND -eq 1 ]] && cmd_exists VBoxManage; then
    EXT_INFO=$(VBoxManage list extpacks 2>/dev/null)
    if echo "$EXT_INFO" | grep -q "Oracle VirtualBox Extension Pack"; then
        EXT_VER=$(echo "$EXT_INFO" | grep "^Version:" | awk '{print $2}' | head -1)
        EXT_MM=$(major_minor "${EXT_VER%%r*}")
        VBX_MM_CLEAN=$(major_minor "${VBX_VER%%r*}")
        if [[ "$EXT_MM" == "$VBX_MM_CLEAN" ]]; then
            ok "Extension Pack $EXT_VER"
            EXT_OK=1
        else
            need "Extension Pack $EXT_VER does not match VirtualBox $VBX_VER"
            ext_pack_cmds
        fi
    else
        need "VirtualBox Extension Pack not installed"
        ext_pack_cmds
    fi
fi

# Vagrant
VGR_FOUND=0
if cmd_exists vagrant; then
    VGR_VER=$(vagrant --version 2>/dev/null | awk '{print $2}')
    VGR_MM=$(major_minor "$VGR_VER")
    if [[ "$VGR_MM" == "$EXP_VGR" ]]; then
        ok "Vagrant $VGR_VER"
    else
        need "Vagrant $VGR_VER — expected $EXP_VGR.x"
        case "$OS_TYPE" in
            macos)
                cmd "brew uninstall --cask vagrant"
                cmd "brew install --cask vagrant"
                note "if Homebrew cask is not $EXP_VGR.x, download directly: developer.hashicorp.com/vagrant/install"
                ;;
            linux)
                note "remove current version and reinstall:"
                case "$LINUX_FLAVOR" in
                    debian) cmd "sudo apt-get remove -y vagrant" ;;
                    rhel)   cmd "sudo dnf remove -y vagrant" ;;
                esac
                note "then follow the install steps below"
                ;;
        esac
    fi
    VGR_FOUND=1
else
    need "Vagrant not installed"
    case "$OS_TYPE" in
        macos)
            cmd "brew install --cask vagrant"
            note "if Homebrew cask is not $EXP_VGR.x, download directly: developer.hashicorp.com/vagrant/install"
            ;;
        linux)
            case "$LINUX_FLAVOR" in
                debian)
                    cmd "wget -O- https://apt.releases.hashicorp.com/gpg \\"
                    cmd "    | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
                    cmd "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \\"
                    cmd "    https://apt.releases.hashicorp.com $LINUX_CODENAME main\" \\"
                    cmd "    | sudo tee /etc/apt/sources.list.d/hashicorp.list"
                    cmd "sudo apt-get update"
                    cmd "sudo apt-get install -y vagrant"
                    ;;
                rhel)
                    cmd "sudo dnf install -y yum-utils"
                    cmd "sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo"
                    cmd "sudo dnf install -y vagrant"
                    ;;
            esac
            ;;
    esac
fi

# Vagrant plugins
if [[ $VGR_FOUND -eq 1 ]]; then
    PLUGINS=$(vagrant plugin list 2>/dev/null)

    if echo "$PLUGINS" | grep -q "vagrant-hostmanager"; then
        HM_VER=$(echo "$PLUGINS" | grep "vagrant-hostmanager" | awk '{print $2}' | tr -d '(),')
        if [[ "$HM_VER" == "$EXP_HM" ]]; then
            ok "vagrant-hostmanager $HM_VER"
        else
            need "vagrant-hostmanager $HM_VER — expected $EXP_HM"
            cmd "vagrant plugin uninstall vagrant-hostmanager"
            cmd "vagrant plugin install vagrant-hostmanager --plugin-version $EXP_HM"
        fi
    else
        need "vagrant-hostmanager not installed"
        cmd "vagrant plugin install vagrant-hostmanager --plugin-version $EXP_HM"
    fi

    if echo "$PLUGINS" | grep -q "vagrant-vbguest"; then
        VBG_VER=$(echo "$PLUGINS" | grep "vagrant-vbguest" | awk '{print $2}' | tr -d '(),')
        if [[ "$VBG_VER" == "$EXP_VBG" ]]; then
            ok "vagrant-vbguest $VBG_VER"
        else
            need "vagrant-vbguest $VBG_VER — expected $EXP_VBG"
            cmd "vagrant plugin uninstall vagrant-vbguest"
            cmd "vagrant plugin install vagrant-vbguest --plugin-version $EXP_VBG"
        fi
    else
        need "vagrant-vbguest not installed"
        cmd "vagrant plugin install vagrant-vbguest --plugin-version $EXP_VBG"
    fi
fi

# ── Host Configuration ────────────────────────────────────────────────────────
section "Host Configuration"

# /etc/vbox/networks.conf
NETS_CONF="/etc/vbox/networks.conf"
if [[ -f "$NETS_CONF" ]]; then
    if grep -q "0\.0\.0\.0/0" "$NETS_CONF"; then
        ok "$NETS_CONF"
    else
        need "$NETS_CONF exists but does not allow 0.0.0.0/0 — VirtualBox may block 172.16.100.0/24"
        cmd "echo '* 0.0.0.0/0 ::/0' | sudo tee $NETS_CONF"
    fi
else
    need "$NETS_CONF not found — VirtualBox will block host-only ranges outside 192.168.56.0/21"
    cmd "sudo mkdir -p /etc/vbox"
    cmd "echo '* 0.0.0.0/0 ::/0' | sudo tee $NETS_CONF"
fi

# vboxnet1 host-only adapter
if [[ $VBX_FOUND -eq 1 ]]; then
    HO_INFO=$(VBoxManage list hostonlynets 2>/dev/null)
    HO_IP_FIELD="LowerIP:"
    if [[ -z "$HO_INFO" ]]; then
        HO_INFO=$(VBoxManage list hostonlyifs 2>/dev/null)
        HO_IP_FIELD="IPAddress:"
    fi

    if echo "$HO_INFO" | grep -q "Name:.*vboxnet1"; then
        HO_IP=$(echo "$HO_INFO" | awk "/^Name:/{found=0} /Name:.*vboxnet1/{found=1} found && /LowerIP:|IPAddress:/{print \$2; exit}")
        if [[ "$HO_IP" == "172.16.100.1" ]]; then
            ok "vboxnet1 — $HO_IP"
        else
            need "vboxnet1 exists but IP is $HO_IP — expected 172.16.100.1"
            cmd "VBoxManage hostonlynet modify --name vboxnet1 --lower-ip 172.16.100.1 --upper-ip 172.16.100.199 --netmask 255.255.255.0"
            note "or reconfigure via VirtualBox GUI: File → Tools → Network Manager → Host-only Networks"
        fi
    else
        need "vboxnet1 not found"
        note "if vboxnet0 does not exist, run the add command twice — adapters are named sequentially:"
        cmd "VBoxManage hostonlynet add --name vboxnet0 --lower-ip 192.168.56.1 --upper-ip 192.168.56.199 --netmask 255.255.255.0 --enable"
        cmd "VBoxManage hostonlynet add --name vboxnet1 --lower-ip 172.16.100.1 --upper-ip 172.16.100.199 --netmask 255.255.255.0 --enable"
        note "or create via VirtualBox GUI: File → Tools → Network Manager → Host-only Networks → Create"
    fi
fi

# VSL_Network NAT network
if [[ $VBX_FOUND -eq 1 ]]; then
    if VBoxManage list natnetworks 2>/dev/null | grep -q "VSL_Network"; then
        ok "VSL_Network NAT network"
    else
        need "VSL_Network NAT network not found"
        cmd "VBoxManage natnetwork add --netname VSL_Network --network '10.0.2.0/24' --enable"
        note "or create via VirtualBox GUI: File → Tools → Network Manager → NAT Networks → Create"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BLD}${CYN}── Summary${RST}"
if [[ $ACTIONS -eq 0 ]]; then
    echo -e "  ${GRN}Nothing to do — environment looks good.${RST}"
    echo -e "  Run ${CYN}./check.sh${RST} to verify before running ${CYN}vagrant up${RST}."
else
    echo -e "  ${YEL}$ACTIONS item(s) need attention.${RST}"
    echo -e "  Run the commands above, then re-run ${CYN}./setup.sh${RST} to confirm, and ${CYN}./check.sh${RST} to verify."
fi
