# vsl2

Multi-VM Vagrant lab environment using VirtualBox as the provider.
Hosts 11 VMs across multiple Linux distributions for IaaS development and testing.

---

## VM Inventory

| VM         | Box                    | Distro         | IP              | SSH   | HTTP  | HTTPS  |
|------------|------------------------|----------------|-----------------|-------|-------|--------|
| otto-svr   | ALMA-8 (local)         | AlmaLinux 8    | 172.16.100.11   | 2211  | 8011  | 11443  |
| rhel-01    | ROCKY-8 (local)        | Rocky Linux 8  | 172.16.100.12   | 2212  | 8012  | 12443  |
| rhel-02    | ROCKY-9 (local)        | Rocky Linux 9  | 172.16.100.13   | 2213  | 8013  | 13443  |
| oracle-01  | ORACLE-8 (local)       | Oracle Linux 8 | 172.16.100.14   | 2214  | 8014  | 14443  |
| oracle-02  | ekko919/Oracle-8.x     | Oracle Linux 8 | 172.16.100.15   | 2215  | 8015  | 15443  |
| debian-01  | DEBIAN-11 (local)      | Debian 11      | 172.16.100.16   | 2216  | 8016  | 16443  |
| debian-02  | DEBIAN-12 (local)      | Debian 12      | 172.16.100.17   | 2217  | 8017  | 17443  |
| suse-01    | ekko919/SUSE-15.x      | openSUSE 15    | 172.16.100.18   | 2218  | 8018  | 18443  |
| suse-02    | ekko919/SUSE-15.x      | openSUSE 15    | 172.16.100.19   | 2219  | 8019  | 19443  |
| pvu-98     | ekko919/Debian-12.x    | Debian 12      | 172.16.100.98   | 2298  | 8098  | 9843   |
| pvu-99     | ekko919/Rocky-9.x      | Rocky Linux 9  | 172.16.100.99   | 2299  | 8099  | 9943   |

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| [VirtualBox](https://www.virtualbox.org/wiki/Downloads) | 7.1.x | Primary hypervisor |
| [VirtualBox Extension Pack](https://www.virtualbox.org/wiki/Downloads) | 7.1.x | Must match VirtualBox version |
| [Vagrant](https://developer.hashicorp.com/vagrant/install) | 2.4.x | VM orchestration |

> **macOS note:** All of the above can be installed via Homebrew:
> ```bash
> brew install --cask virtualbox
> brew install --cask virtualbox-extension-pack
> brew install --cask vagrant
> ```

---

## Vagrant Plugins

Two Vagrant plugins are required:

```bash
vagrant plugin install vagrant-hostmanager
vagrant plugin install vagrant-vbguest
```

| Plugin | Purpose |
|--------|---------|
| `vagrant-hostmanager` | Manages `/etc/hosts` entries across VMs |
| `vagrant-vbguest` | Manages VirtualBox Guest Additions on VMs |

---

## Host Configuration

These steps configure the local host before the environment can be used.
Tested on macOS — steps should be similar on Linux.

### 1. VirtualBox Network Permissions

Create `/etc/vbox/networks.conf` and add the following:

```
* 0.0.0.0/0 ::/0
```

This allows VirtualBox to create host-only adapters on any IP range.

### 2. Host-Only Network Adapter (vboxnet1)

The lab uses a dedicated host-only adapter for the private network (`172.16.100.0/24`).

1. Open VirtualBox and go to **File → Host Network Manager**
2. Create a new adapter — it will default to `vboxnet0`. If `vboxnet0` already exists, create another — it will be named `vboxnet1`
3. Select `vboxnet1` and click **Properties**
4. Choose **Configure Adapter Manually**
5. Set the following:
   - **IPv4 Address:** `172.16.100.1`
   - **Subnet Mask:** `255.255.255.0`
6. Disable the DHCP Server on this adapter
7. Click **Apply**

> **Note:** On macOS, you may need to click Apply twice due to a VirtualBox GUI bug.

### 3. NAT Network (VSL_Network)

The lab VMs use a shared NAT network for outbound internet access.

1. In VirtualBox, go to **File → Tools → Network Manager**
2. Select the **NAT Networks** tab
3. Click **Create**
4. Set the name to `VSL_Network`
5. Click **Apply**

---

## Vagrant Boxes

VMs marked `(local)` in the inventory require locally-built Vagrant boxes registered
in your Vagrant box list. These are produced by the `auto.packer` project.

Verify your local boxes are registered before bringing up the environment:

```bash
vagrant box list
```

Expected local boxes:

| Box Name   | Built From         |
|------------|--------------------|
| ALMA-8     | auto.packer vgr-alma-8.json   |
| ROCKY-8    | auto.packer vgr-rocky-8.json  |
| ROCKY-9    | auto.packer vgr-rocky-9.json  |
| ORACLE-8   | auto.packer vgr-oracle-8.json |
| DEBIAN-11  | auto.packer vgr-deb-11.json   |
| DEBIAN-12  | auto.packer vgr-deb-12.json   |

---

## SSH Key Convention

The `keys/.ssh/` directory contains a shared key pair (`vagrant.key` / `vagrant.pub`)
committed intentionally to the repository. This follows the same convention as
Vagrant's built-in insecure key — it is not a security credential, it is a known
lab key that allows Vagrant to SSH into freshly provisioned VMs before any
org-specific access is configured.

The `vagrant.pub` key is written to `~/.ssh/authorized_keys` on each VM during
provisioning, replacing the default Vagrant insecure key. All VMs in the environment
share this key pair.

**These VMs are only reachable from the local machine** (host-only adapter +
localhost-bound forwarded ports). Do not use this key pair on any externally
accessible system.

---

## Local Customization

Two values in the `Vagrantfile` are site-specific and should be reviewed before
first use:

**Timezone** — All VMs are provisioned with `America/New_York`. To change it,
update the `timedatectl set-timezone` line in the `$ntp_svc` script block near
the top of the `Vagrantfile`:

```ruby
timedatectl set-timezone America/New_York
```

Replace with any valid `timedatectl` timezone string (e.g., `America/Chicago`,
`Europe/London`). Run `timedatectl list-timezones` to see all options.

**Host-only adapter name** — The private network adapter is set to `vboxnet1`
throughout the `Vagrantfile`. On Windows the name will differ — each VM block
has the Windows equivalent commented out directly above or below the active line.

---

## Clone and Run

Clone into the following path — the directory structure is expected by the environment:

```
~/My Documents/VM_Share/Projects/IaaS/vsl2
```

```bash
git clone https://github.com/ekko919/vsl2.git
cd vsl2
```

---

## Common Commands

```bash
# Bring up the full environment
vagrant up

# Bring up a single VM
vagrant up <vm-name>

# SSH into a VM
vagrant ssh <vm-name>

# Halt all VMs
vagrant halt

# Halt a single VM
vagrant halt <vm-name>

# Destroy all VMs
vagrant destroy -f

# Check VM status
vagrant status
```
