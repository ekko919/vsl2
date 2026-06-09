# vsl2

Multi-VM Vagrant lab environment using VirtualBox as the provider.
Hosts 11 VMs across multiple Linux distributions for IaaS development and testing.

---

## Table of Contents

- [VM Inventory](#vm-inventory)
- [Prerequisites](#prerequisites)
- [Host Configuration](#host-configuration)
- [Vagrant Boxes](#vagrant-boxes)
- [Local Customization](#local-customization)
- [Pre-flight Check](#quick-start)
- [Quick Start](#quick-start)
- [Common Commands](#common-commands)
- [SSH Key Convention](#ssh-key-convention)

---

## VM Inventory

| VM        | Distro         | IP            | SSH  | HTTP | HTTPS |
|-----------|----------------|---------------|------|------|-------|
| otto-svr  | AlmaLinux 8    | 172.16.100.11 | 2211 | 8011 | 11443 |
| rhel-01   | Rocky Linux 8  | 172.16.100.12 | 2212 | 8012 | 12443 |
| rhel-02   | Rocky Linux 9  | 172.16.100.13 | 2213 | 8013 | 13443 |
| oracle-01 | Oracle Linux 8 | 172.16.100.14 | 2214 | 8014 | 14443 |
| oracle-02 | Oracle Linux 8 | 172.16.100.15 | 2215 | 8015 | 15443 |
| debian-01 | Debian 11      | 172.16.100.16 | 2216 | 8016 | 16443 |
| debian-02 | Debian 12      | 172.16.100.17 | 2217 | 8017 | 17443 |
| suse-01   | openSUSE 15    | 172.16.100.18 | 2218 | 8018 | 18443 |
| suse-02   | openSUSE 15    | 172.16.100.19 | 2219 | 8019 | 19443 |
| pvu-98    | Debian 12      | 172.16.100.98 | 2298 | 8098 | 9843  |
| pvu-99    | Rocky Linux 9  | 172.16.100.99 | 2299 | 8099 | 9943  |

All VMs share the `172.16.100.0/24` private network and use dnsmasq for internal DNS
resolution under the `vsl.lab` domain. Forwarded ports are bound to `localhost` only.

---

## Prerequisites

### Tools

| Tool | Version | Notes |
|------|---------|-------|
| [VirtualBox](https://www.virtualbox.org/wiki/Downloads) | 7.1.x | Primary hypervisor |
| [VirtualBox Extension Pack](https://www.virtualbox.org/wiki/Downloads) | 7.1.x | Must match VirtualBox version exactly |
| [Vagrant](https://developer.hashicorp.com/vagrant/install) | 2.4.x | VM orchestration |

On macOS all three can be installed via Homebrew:

```bash
brew install --cask virtualbox virtualbox-extension-pack vagrant
```

### Vagrant Plugins

Install pinned versions to match the tested configuration:

```bash
vagrant plugin install vagrant-hostmanager --plugin-version 1.8.10
vagrant plugin install vagrant-vbguest --plugin-version 0.32.0
```

| Plugin | Version | Purpose |
|--------|---------|---------|
| `vagrant-hostmanager` | 1.8.10 | Manages `/etc/hosts` entries across VMs |
| `vagrant-vbguest` | 0.32.0 | Manages VirtualBox Guest Additions on VMs |

Other versions may work but have not been tested against this environment.

---

## Host Configuration

One-time setup required before the environment can be used. Tested on macOS — steps
are similar on Linux.

### 1. VirtualBox Network Permissions

Create `/etc/vbox/networks.conf`:

```
* 0.0.0.0/0 ::/0
```

This allows VirtualBox to create host-only adapters on any IP range.

### 2. Host-Only Adapter (vboxnet1)

The lab uses a dedicated host-only adapter for the `172.16.100.0/24` private network.

1. Open VirtualBox → **File → Host Network Manager**
2. Create a new adapter — name it `vboxnet1` (create `vboxnet0` first if it doesn't exist)
3. Select `vboxnet1` → **Properties** → **Configure Adapter Manually**
4. Set **IPv4 Address** to `172.16.100.1`, **Subnet Mask** to `255.255.255.0`
5. Disable the DHCP Server
6. Click **Apply**

> On macOS you may need to click Apply twice due to a VirtualBox GUI bug.

### 3. NAT Network (VSL_Network)

The lab VMs use a shared NAT network for outbound internet access.

1. Open VirtualBox → **File → Tools → Network Manager → NAT Networks**
2. Click **Create**, set the name to `VSL_Network`
3. Click **Apply**

---

## Vagrant Boxes

VMs source their base images from two places:

- **HCP Registry** (`ekko919/*`) — publicly available boxes pulled automatically by Vagrant
- **Local** — boxes built with [auto.packer](https://github.com/ekko919/auto.packer) and registered locally

Before bringing up the full environment, verify your local boxes are registered:

```bash
vagrant box list
```

Required local boxes:

| Box Name  | Build Template              |
|-----------|-----------------------------|
| ALMA-8    | auto.packer `vgr-alma-8.json`   |
| ROCKY-8   | auto.packer `vgr-rocky-8.json`  |
| ROCKY-9   | auto.packer `vgr-rocky-9.json`  |
| ORACLE-8  | auto.packer `vgr-oracle-8.json` |
| DEBIAN-11 | auto.packer `vgr-deb-11.json`   |
| DEBIAN-12 | auto.packer `vgr-deb-12.json`   |

---

## Local Customization

Two values in the `Vagrantfile` are site-specific and should be reviewed before
first use.

### Timezone

All VMs are provisioned with `America/New_York`. To change it, update the
`timedatectl set-timezone` line in the `$ntp_svc` block near the top of the
`Vagrantfile`:

```ruby
timedatectl set-timezone America/New_York
```

Replace with any valid timezone string. Run `timedatectl list-timezones` for the
full list.

### Host-Only Adapter Name

The adapter name `vboxnet1` is used throughout the `Vagrantfile`. On Windows the
name follows a different schema — the Windows equivalent is commented out directly
alongside the active line in each VM block.

---

## Quick Start

Run the pre-flight check first to verify all prerequisites and host configuration:

```bash
./check.sh
```

This checks VirtualBox, Vagrant, plugins, host-only adapter, NAT network, local boxes,
and port availability — and tells you exactly what needs to be fixed before `vagrant up`.

After all checks pass:

```bash
git clone https://github.com/ekko919/vsl2.git
cd vsl2

# Bring up the full environment
vagrant up

# Or bring up a single VM to start
vagrant up otto-svr
```

> **Clone path note:** The Vagrantfile expects to be cloned into a path with no
> spaces in its parent directories on Linux/macOS. The default
> `~/My Documents/VM_Share/Projects/IaaS/vsl2` works on macOS because Vagrant
> handles the space internally, but bare shell operations in that directory may
> require quoting.

---

## Common Commands

```bash
vagrant up                  # Bring up all VMs
vagrant up <vm-name>        # Bring up a single VM
vagrant ssh <vm-name>       # Open SSH session
vagrant halt                # Halt all VMs
vagrant halt <vm-name>      # Halt a single VM
vagrant destroy -f          # Destroy all VMs
vagrant status              # Show VM states
vagrant box list            # List locally registered boxes
```

---

## SSH Key Convention

The `keys/.ssh/` directory contains a shared key pair (`vagrant.key` / `vagrant.pub`)
committed intentionally to the repository. This follows the same convention as
Vagrant's built-in insecure key — it is a known lab key that gives Vagrant SSH access
to freshly provisioned VMs before any org-specific accounts exist.

During provisioning, `vagrant.pub` is written to `~/.ssh/authorized_keys` on each VM,
replacing the default Vagrant insecure key. All VMs in the environment share this
key pair.

**These VMs are only reachable from the local machine** (host-only adapter +
`localhost`-bound forwarded ports). Do not use this key pair on any
externally accessible system.
