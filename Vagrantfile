# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
#
#############################################
#           VAGRANT GUEST SCRIPTS           #
#############################################
$disable_ipv6 = <<-'SCRIPT'
echo Disable IPv6 Listener
cp /media/tmp/sysctl.conf /etc/sysctl.conf
awk 'NR==18 {$0="AddressFamily inet"} 1' /etc/ssh/sshd_config > /etc/ssh/sshd_config.tmp
mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
SCRIPT

###############################
$dnsmasq_conf = <<-SCRIPT
echo Provisioning DNSMASQ file
rm -f /etc/dnsmasq.conf
cp /media/tmp/dnsmasq.conf /etc/dnsmasq.conf
SCRIPT

###############################
$if_schema = <<-'SCRIPT'
# Get the list of network connections
connections=$(nmcli -t -f NAME,DEVICE con show)

# Check if any connections have the name 'System eth'
if echo "$connections" | grep -q 'System eth'; then
  echo "Found connections named 'System eth'. Renaming..."

  # Loop through each connection and rename it
  while read -r line; do
    connection=$(echo "$line" | cut -d: -f1)
    device=$(echo "$line" | cut -d: -f2)

    if [[ $connection == *"System eth"* ]]; then
      new_name=$(echo "$connection" | sed 's/System eth/eth/')

      # Rename the connection and associate it with the correct device
      nmcli con modify "$connection" connection.id "$new_name" connection.interface-name "$device"
      echo "Renamed connection '$connection' to '$new_name' and associated it with device '$device'"
    fi
  done <<< "$connections"

  echo "Connections renamed successfully."
else
  echo "No connections named 'System eth' found."
fi

# Remove any auto-generated stale profiles
nmcli con delete "Wired connection 1" 2>/dev/null || true
SCRIPT

###############################
$vsl_hosts = <<-SCRIPT
echo Provisioning HOSTS file
rm -f /etc/hosts
cp /media/tmp/ag-hosts /etc/hosts
SCRIPT

###############################
$vsl_svr_hosts = <<-SCRIPT
echo Provisioning HOSTS file
rm -f /etc/hosts
cp /media/tmp/svr-hosts /etc/hosts
SCRIPT

###############################
$ntp_svc = <<-'SCRIPT'
echo 'setting TimeZone & NTP Services'
timedatectl set-timezone America/New_York
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_FAMILY=${ID_LIKE:-$ID}
fi
case "$OS_FAMILY" in
    *debian*)
        NTP_SVC="chrony"
        ;;
    *)
        NTP_SVC="chronyd"
        ;;
esac
systemctl start $NTP_SVC
systemctl enable $NTP_SVC
chronyc makestep
echo ...
echo Done.
SCRIPT

###############################
$resolv_conf = <<-SCRIPT
echo Provisioning RESOLVER file
rm -f /etc/resolv.conf
cp /media/tmp/resolv.conf /etc/resolv.conf
SCRIPT

#############################################
#     VAGRANT HOST MANAGER CONFIGURATION    #
#############################################

Vagrant.configure("2") do |config|
	config.vm.box_check_update = true
	config.vm.boot_timeout = 300
	# SSH Key Config
	config.ssh.forward_agent = false
	config.ssh.insert_key = false
	config.ssh.private_key_path = ["keys/.ssh/vagrant.key", "~/.vagrant.d/insecure_private_key"]
	config.vm.provision "file", source: "keys/.ssh/vagrant.pub", destination: "~/.ssh/authorized_keys"

	# Configure Vagrant-HostManager Plugin
	if Vagrant.has_plugin? "vagrant-hostmanager"
		config.hostmanager.enabled = false
		config.hostmanager.manage_host = true
		config.hostmanager.ignore_private_ip = false
		config.hostmanager.include_offline = true
	end

	# Configure vagrant-vbguest Plugin
	if Vagrant.has_plugin? "vagrant-vbguest"
		config.vbguest.no_install = true
		config.vbguest.auto_update = false
		config.vbguest.no_remote = true
	end

#############################################
#      AUTOMATION SERVER CONFIGURATION      #
#############################################

	config.vm.define "otto-svr" do |vm1|
		vm1.vm.network :forwarded_port, guest: 22, host: 2211, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm1.vm.network :forwarded_port, guest: 80, host: 8011, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm1.vm.network :forwarded_port, guest: 443, host: 11443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm1.vm.hostname = "otto-svr"
		vm1.vm.box = "ekko919/Alma-8.x"
		vm1.vm.box_version = "2026.04.02"
		vm1.vm.synced_folder ".", "/vagrant", disabled: true
		vm1.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm1.vm.network "private_network",
						ip: "172.16.100.11",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm1.vm.provider "virtualbox" do |vb|
			vb.name = "Linux.OS (Otto SVR)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm1.vm.provision "shell", inline: $disable_ipv6
		vm1.vm.provision "shell", inline: 'sysctl -p'
		vm1.vm.provision "shell", inline: $if_schema
		vm1.vm.provision "shell", inline: $vsl_svr_hosts
		vm1.vm.provision "shell", inline: <<-SHELL
			yum clean all
			SHELL
		vm1.vm.provision "shell", inline: <<-SHELL
			yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
			yum -y install nano gcc make perl kernel-devel
			yum -y install bind-utils chrony
			systemctl set-default multi-user.target
			SHELL
		vm1.vm.provision "shell", inline: $resolv_conf
		vm1.vm.provision "shell", inline: <<-SHELL
			yum -y install dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm1.vm.provision "shell", inline: $ntp_svc
	end

#############################################
#              RHEL Linux (01)              #
#############################################

	config.vm.define "rhel-01" do |vm2|
		vm2.vm.network :forwarded_port, guest: 22, host: 2212, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm2.vm.network :forwarded_port, guest: 80, host: 8012, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm2.vm.network :forwarded_port, guest: 443, host: 12443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm2.vm.hostname = "rhel-01"
		vm2.vm.box = "ekko919/Rocky-8.x"
		vm2.vm.box_version = "2026.04.02"
		vm2.vm.synced_folder ".", "/vagrant", disabled: true
		vm2.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm2.vm.network "private_network",
						ip: "172.16.100.12",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm2.vm.provider "virtualbox" do |vb|
			vb.name = "RHEL (Client AG12)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm2.vm.provision "shell", inline: $if_schema
		vm2.vm.provision "shell", inline: $vsl_hosts
		vm2.vm.provision "shell", inline: <<-SHELL
			yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
			yum -y install nano gcc make perl kernel-devel
			yum -y install bind-utils
			systemctl set-default multi-user.target
			SHELL
		vm2.vm.provision "shell", inline: <<-SHELL
			yum -y install dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm2.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#              RHEL Linux (02)              #
#############################################

	config.vm.define "rhel-02" do |vm3|
		vm3.vm.network :forwarded_port, guest: 22, host: 2213, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm3.vm.network :forwarded_port, guest: 80, host: 8013, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm3.vm.network :forwarded_port, guest: 443, host: 13443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm3.vm.hostname = "rhel-02"
		vm3.vm.box = "ekko919/Rocky-9.x"
		vm3.vm.box_version = "2026.04.02"
		vm3.vm.synced_folder ".", "/vagrant", disabled: true
		vm3.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm3.vm.network "private_network",
						ip: "172.16.100.13",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm3.vm.provider "virtualbox" do |vb|
			vb.name = "RHEL (Client AG13)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm3.vm.provision "shell", inline: $if_schema
		vm3.vm.provision "shell", inline: $vsl_hosts
		vm3.vm.provision "shell", inline: <<-SHELL
			yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
			yum -y install nano gcc make perl kernel-devel
			yum -y install bind-utils
			systemctl set-default multi-user.target
			SHELL
		vm3.vm.provision "shell", inline: <<-SHELL
			yum -y install dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm3.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#             Oracle Linux (01)             #
#############################################

	config.vm.define "oracle-01" do |vm4|
		vm4.vm.network :forwarded_port, guest: 22, host: 2214, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm4.vm.network :forwarded_port, guest: 80, host: 8014, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm4.vm.network :forwarded_port, guest: 443, host: 14443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm4.vm.hostname = "oracle-01"
		vm4.vm.box = "ekko919/Oracle-8.x"
		vm4.vm.box_version = "2026.04.02"
		vm4.vm.synced_folder ".", "/vagrant", disabled: true
		vm4.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm4.vm.network "private_network",
						ip: "172.16.100.14",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm4.vm.provider "virtualbox" do |vb|
			vb.name = "Oracle Linux (Client AG14)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm4.vm.provision "shell", inline: $if_schema
		vm4.vm.provision "shell", inline: $vsl_hosts
		vm4.vm.provision "shell", inline: <<-SHELL
			yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
			yum -y install nano gcc make perl kernel-devel
			yum -y install bind-utils
			systemctl set-default multi-user.target
			SHELL
		vm4.vm.provision "shell", inline: <<-SHELL
			yum -y install dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm4.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#             Oracle Linux (02)             #
#############################################

	config.vm.define "oracle-02" do |vm5|
		vm5.vm.network :forwarded_port, guest: 22, host: 2215, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm5.vm.network :forwarded_port, guest: 80, host: 8015, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm5.vm.network :forwarded_port, guest: 443, host: 15443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm5.vm.hostname = "oracle-02"
		vm5.vm.box = "ekko919/Oracle-8.x"
		vm5.vm.box_version = "2026.04.02"
		vm5.vm.synced_folder ".", "/vagrant", disabled: true
		vm5.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm5.vm.network "private_network",
						ip: "172.16.100.15",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm5.vm.provider "virtualbox" do |vb|
			vb.name = "Oracle Linux (Client AG15)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm5.vm.provision "shell", inline: $if_schema
		vm5.vm.provision "shell", inline: $vsl_hosts
		vm5.vm.provision "shell", inline: <<-SHELL
			yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
			yum -y install nano gcc make perl kernel-devel
			yum -y install bind-utils
			systemctl set-default multi-user.target
			SHELL
		vm5.vm.provision "shell", inline: <<-SHELL
			yum -y install dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm5.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#             Debian Linux (01)             #
#############################################

	config.vm.define "debian-01" do |vm6|
		vm6.vm.network :forwarded_port, guest: 22, host: 2216, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm6.vm.network :forwarded_port, guest: 80, host: 8016, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm6.vm.network :forwarded_port, guest: 443, host: 16443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm6.vm.hostname = "debian-01"
		vm6.vm.box = "ekko919/Debian-11.x"
		vm6.vm.box_version = "2026.04.02"
		vm6.vm.synced_folder ".", "/vagrant", disabled: true
		vm6.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm6.vm.network "private_network",
						ip: "172.16.100.16",
						name: "vboxnet1",                                 # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2",  # Windows Network Naming Schema
						auto_config: false
		vm6.vm.provider "virtualbox" do |vb|
			vb.name = "Debian Linux (Client AG16)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm6.vm.provision "shell", inline: <<-SHELL
			nmcli connection add type ethernet ifname eth1 con-name eth1 ip4 172.16.100.16/24 gw4 172.16.100.1 autoconnect yes
			nmcli connection up eth1
			nmcli con delete "Wired connection 1" 2>/dev/null || true
			SHELL
		vm6.vm.provision "shell", inline: <<-SHELL
			apt-get update
			apt-get install -y linux-headers-generic dkms
			SHELL
		vm6.vm.provision "shell", inline: $vsl_hosts
		vm6.vm.provision "shell", inline: <<-SHELL
			apt-get install nano gcc make perl linux-headers-$(uname -r) -y
			apt-get install bind9utils -y
			systemctl set-default multi-user.target
			SHELL
		vm6.vm.provision "shell", inline: <<-SHELL
			apt-get install -y dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm6.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#             Debian Linux (02)             #
#############################################

	config.vm.define "debian-02" do |vm7|
		vm7.vm.network :forwarded_port, guest: 22, host: 2217, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm7.vm.network :forwarded_port, guest: 80, host: 8017, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm7.vm.network :forwarded_port, guest: 443, host: 17443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm7.vm.hostname = "debian-02"
		vm7.vm.box = "ekko919/Debian-12.x"
		vm7.vm.box_version = "2026.04.02"
		vm7.vm.synced_folder ".", "/vagrant", disabled: true
		vm7.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm7.vm.network "private_network",
						ip: "172.16.100.17",
						name: "vboxnet1",                                 # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2",  # Windows Network Naming Schema
						auto_config: false
		vm7.vm.provider "virtualbox" do |vb|
			vb.name = "Debian Linux (Client AG17)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm7.vm.provision "shell", inline: <<-SHELL
			nmcli connection add type ethernet ifname eth1 con-name eth1 ip4 172.16.100.17/24 gw4 172.16.100.1 autoconnect yes
			nmcli connection up eth1
			nmcli con delete "Wired connection 1" 2>/dev/null || true
			SHELL
		vm7.vm.provision "shell", inline: <<-SHELL
			apt-get update
			apt-get install -y linux-headers-generic dkms
			SHELL
		vm7.vm.provision "shell", inline: $vsl_hosts
		vm7.vm.provision "shell", inline: <<-SHELL
			apt-get install nano gcc make perl linux-headers-$(uname -r) -y
			apt-get install bind9utils -y
			systemctl set-default multi-user.target
			SHELL
		vm7.vm.provision "shell", inline: <<-SHELL
			apt-get install -y dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm7.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#            openSUSE Linux (01)            #
#############################################

	config.vm.define "suse-01" do |vm8|
		vm8.vm.network :forwarded_port, guest: 22, host: 2218, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm8.vm.network :forwarded_port, guest: 80, host: 8018, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm8.vm.network :forwarded_port, guest: 443, host: 18443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm8.vm.hostname = "suse-01"
		vm8.vm.box = "ekko919/SUSE-15.x"
		vm8.vm.box_version = "2026.04.03"
		vm8.vm.synced_folder ".", "/vagrant", disabled: true
		vm8.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm8.vm.network "private_network",
						ip: "172.16.100.18",
						name: "vboxnet1",                                 # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2",  # Windows Network Naming Schema
						auto_config: false
		vm8.vm.provider "virtualbox" do |vb|
			vb.name = "openSUSE Linux (Client AG18)"
			vb.gui = false
			vb.memory = "2048"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "SATA Controller",
						"--port", "1", "--device", "0",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm8.vm.provision "shell", inline: <<-SHELL
			nmcli connection add type ethernet ifname eth1 con-name eth1 ip4 172.16.100.18/24 gw4 172.16.100.1 autoconnect yes
			nmcli connection up eth1
			SHELL
		vm8.vm.provision "shell", inline: $vsl_hosts
		vm8.vm.provision "shell", inline: <<-SHELL
			zypper in -y wget nano bind-utils
			SHELL
		vm8.vm.provision "shell", inline: <<-SHELL
			zypper in -y dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm8.vm.provision "shell", inline: <<-SHELL
			systemctl set-default multi-user.target
			SHELL
		vm8.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#            openSUSE Linux (02)            #
#############################################

	config.vm.define "suse-02" do |vm9|
		vm9.vm.network :forwarded_port, guest: 22, host: 2219, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm9.vm.network :forwarded_port, guest: 80, host: 8019, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm9.vm.network :forwarded_port, guest: 443, host: 19443, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm9.vm.hostname = "suse-02"
		vm9.vm.box = "ekko919/SUSE-15.x"
		vm9.vm.box_version = "2026.04.03"
		vm9.vm.synced_folder ".", "/vagrant", disabled: true
		vm9.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm9.vm.network "private_network",
						ip: "172.16.100.19",
						name: "vboxnet1",                                 # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2",  # Windows Network Naming Schema
						auto_config: false
		vm9.vm.provider "virtualbox" do |vb|
			vb.name = "openSUSE Linux (Client AG19)"
			vb.gui = false
			vb.memory = "2048"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "SATA Controller",
						"--port", "1", "--device", "0",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm9.vm.provision "shell", inline: <<-SHELL
			nmcli connection add type ethernet ifname eth1 con-name eth1 ip4 172.16.100.19/24 gw4 172.16.100.1 autoconnect yes
			nmcli connection up eth1
			SHELL
		vm9.vm.provision "shell", inline: $vsl_hosts
		vm9.vm.provision "shell", inline: <<-SHELL
			zypper in -y wget nano bind-utils
			SHELL
		vm9.vm.provision "shell", inline: <<-SHELL
			zypper in -y dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm9.vm.provision "shell", inline: <<-SHELL
			systemctl set-default multi-user.target
			SHELL
		vm9.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#            PreVu 'APT' (Debian)           #
#############################################

	config.vm.define "pvu-98" do |vm98|
		vm98.ssh.shell = "/bin/bash"    # Declare VM Shell Environment
		vm98.vm.network :forwarded_port, guest: 22, host: 2298, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm98.vm.network :forwarded_port, guest: 80, host: 8098, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm98.vm.network :forwarded_port, guest: 443, host: 9843, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm98.vm.hostname = "pvu-98.vsl.lab"
		vm98.vm.box = "ekko919/Debian-12.x"
		vm98.vm.box_version = "2025.08.18"
		vm98.vm.synced_folder ".", "/vagrant", disabled: true
		vm98.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm98.vm.network "private_network",
						ip: "172.16.100.98",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm98.vm.provider "virtualbox" do |vb|
			vb.name = "PVU_98 (Client AG98)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"16"
						]
			vb.customize ["modifyvm", :id,
						"--nested-hw-virt",
						"on"
						]
			vb.customize ["modifyvm", :id,
						"--uart1",
						"0x3F8", "4"
						]
			vb.customize ["modifyvm", :id,
						"--uartmode1",
						"file", File::NULL
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "IDE Controller",
						"--port", "0", "--device", "1",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		vm98.vm.provision "shell", inline: <<-SHELL
			apt-get update
			apt-get install -y linux-headers-generic dkms wget
			SHELL
		vm98.vm.provision "shell", inline: $vsl_hosts
		vm98.vm.provision "shell", inline: <<-SHELL
			apt-get install nano gcc make perl linux-headers-$(uname -r) -y
			apt-get install bind9utils -y
			systemctl set-default multi-user.target
			SHELL
		vm98.vm.provision "shell", inline: <<-SHELL
			apt-get install -y dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm98.vm.provision "shell", inline: $resolv_conf
	end

#############################################
#            PreVu 'YUM' (Rocky)            #
#############################################

	config.vm.define "pvu-99" do |vm99|
		vm99.vm.network :forwarded_port, guest: 22, host: 2299, host_ip: "127.0.0.1", id: "ssh", auto_correct: true
		vm99.vm.network :forwarded_port, guest: 80, host: 8099, host_ip: "127.0.0.1", id: "http", auto_correct: true
		vm99.vm.network :forwarded_port, guest: 443, host: 9943, host_ip: "127.0.0.1", id: "https", auto_correct: true
		vm99.vm.hostname = "pvu-99.vsl.lab"
		vm99.vm.box = "ekko919/Rocky-9.x"
		vm99.vm.box_version = "2026.04.02"
		vm99.vm.synced_folder ".", "/vagrant", disabled: true
		vm99.vm.synced_folder "tmp", "/media/tmp", create: true,
			owner: "vagrant", group: "vboxsf"
		vm99.vm.network "private_network",
						ip: "172.16.100.99",
						name: "vboxnet1"                                  # macOS/Linux Naming Schema
#						name: "VirtualBox Host-Only Ethernet Adapter#2"   # Windows Network Naming Schema
		vm99.vm.disk :disk, size: "80GB", primary: true
		vm99.vm.provider "virtualbox" do |vb|
			vb.name = "PVU_99 (Client AG99)"
			vb.gui = false
			vb.memory = "1024"
			vb.cpus = 1
			vb.customize ["modifyvm", :id,
						"--vram",
						"128"
						]
			vb.customize ["storageattach", :id,
						"--storagectl", "SATA Controller",
						"--port", "1", "--device", "0",
						"--type", "dvddrive",
						"--medium", "emptydrive"
						]
			vb.customize ["modifyvm", :id,
						"--graphicscontroller", "vmsvga"
						]
			vb.customize ["modifyvm", :id,
						"--audio", "none"
						]
			vb.customize ["modifyvm", :id,
						"--cableconnected1", "on"
						]
			vb.customize ["modifyvm", :id,
						"--nictype2", "82540em",
						"--nic2", "natnetwork",
						"--nat-network2", "VSL_Network",
						"--nicpromisc2", "allow-all"
						]
		end
		# Rocky Linux Guest Additions Failure to load...
		# Run as root: yum install elfutils-libelf-devel -y
		vm99.vm.provision "shell", inline: $vsl_hosts
		vm99.vm.provision "shell", inline: <<-SHELL
			yum install -y wget nano bind-utils
			SHELL
		vm99.vm.provision "shell", inline: $if_schema
		vm99.vm.provision "shell", inline: <<-SHELL
			yum -y install dnsmasq
			echo starting DNS MASQ Service
			systemctl stop dnsmasq || true
			systemctl stop systemd-resolved || true
			systemctl disable systemd-resolved || true
			systemctl mask systemd-resolved || true
			#{$dnsmasq_conf}
			systemctl start dnsmasq
			systemctl enable dnsmasq
			echo ...
			echo Done.
			SHELL
		vm99.vm.provision "shell", inline: <<-SHELL
			systemctl set-default multi-user.target
			SHELL
		vm99.vm.provision "shell", inline: $resolv_conf
	end
end
