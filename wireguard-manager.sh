#!/bin/bash
# https://github.com/complexorganizations/wireguard-manager

# Require script to be run as root
function super-user-check() {
  if [ "$EUID" -ne 0 ]; then
    echo "You need to run this script as super user."
    exit
  fi
}

# Check for root
super-user-check

# Checking For Virtualization
function virt-check() {
  # Deny OpenVZ Virtualization
  if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo "OpenVZ virtualization is not supported (yet)."
    exit
  # Deny LXC Virtualization
  elif [ "$(systemd-detect-virt)" == "lxc" ]; then
    echo "LXC virtualization is not supported (yet)."
    exit
  fi
}

# Virtualization Check
virt-check

# Detect Operating System
function dist-check() {
  if [ -e /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO=$ID
    DISTRO_VERSION=$VERSION_ID
  fi
}

# Check Operating System
dist-check

# Pre-Checks system requirements
function installing-system-requirements() {
  if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ] || [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ] || [ "$DISTRO" == "alpine" ]; }; then
    if { ! [ -x "$(command -v curl)" ] || ! [ -x "$(command -v iptables)" ] || ! [ -x "$(command -v bc)" ] || ! [ -x "$(command -v jq)" ] || ! [ -x "$(command -v sed)" ] || ! [ -x "$(command -v zip)" ] || ! [ -x "$(command -v unzip)" ] || ! [ -x "$(command -v grep)" ] || ! [ -x "$(command -v awk)" ] || ! [ -x "$(command -v ip)" ]; }; then
      if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
        apt-get update && apt-get install iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 -y
      elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
        yum update -y && yum install epel-release iptables curl coreutils bc jq sed e2fsprogs zip unzip grep gawk iproute2 -y
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Syu --noconfirm iptables curl bc jq sed zip unzip grep gawk iproute2
      elif [ "$DISTRO" == "alpine" ]; then
        apk update && apk add iptables curl bc jq sed zip unzip grep gawk iproute2
      fi
    fi
  else
    echo "Error: $DISTRO not supported."
    exit
  fi
}

# Run the function and check for requirements
installing-system-requirements

# Check for docker stuff
function docker-check() {
  if [ -f /.dockerenv ]; then
    DOCKER_KERNEL_VERSION_LIMIT=5.6
    DOCKER_KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
    if (($(echo "$KERNEL_CURRENT_VERSION >= $KERNEL_VERSION_LIMIT" | bc -l))); then
      echo "Correct: Kernel $KERNEL_CURRENT_VERSION supported." >>/dev/null
    else
      echo "Error: Kernel $DOCKER_KERNEL_CURRENT_VERSION not supported, please update to $DOCKER_KERNEL_VERSION_LIMIT"
      exit
    fi
  fi
}

# Docker Check
docker-check

# Lets check the kernel version
function kernel-check() {
  KERNEL_VERSION_LIMIT=3.1
  KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
  if (($(echo "$KERNEL_CURRENT_VERSION >= $KERNEL_VERSION_LIMIT" | bc -l))); then
    echo "Correct: Kernel $KERNEL_CURRENT_VERSION supported." >>/dev/null
  else
    echo "Error: Kernel $KERNEL_CURRENT_VERSION not supported, please update to $KERNEL_VERSION_LIMIT"
    exit
  fi
}

# Kernel Version
kernel-check

# Global variables
WIREGUARD_PATH="/etc/wireguard"
WIREGUARD_PUB_NIC="wg0"
WIREGUARD_CONFIG="$WIREGUARD_PATH/$WIREGUARD_PUB_NIC.conf"
WIREGUARD_MANAGER="$WIREGUARD_PATH/wireguard-manager"
WIREGUARD_INTERFACE="$WIREGUARD_PATH/wireguard-interface"
WIREGUARD_PEER="$WIREGUARD_PATH/wireguard-peer"
WIREGUARD_MANAGER_UPDATE="https://raw.githubusercontent.com/complexorganizations/wireguard-manager/main/wireguard-manager.sh"

# Verify that it is an old installation or another installer
function previous-wireguard-installation() {
  if [ -d "$WIREGUARD_PATH" ]; then
    if [ ! -f "$WIREGUARD_MANAGER" ]; then
      rm -rf $WIREGUARD_PATH
    fi
  fi
}

# Run the function to eliminate old installation or another installer
previous-wireguard-installation

# Which would you like to install interface or peer?
function interface-or-peer() {
  if [ ! -f "$WIREGUARD_MANAGER" ]; then
    echo "Do you want the interface or peer to be installed?"
    echo "  1) Interface"
    echo "  2) Peer"
    until [[ "$INTERFACE_OR_PEER" =~ ^[1-2]$ ]]; do
      read -rp "Interface Or Peer [1-2]: " -e -i 1 INTERFACE_OR_PEER
    done
    case $INTERFACE_OR_PEER in
    1)
      if [ -f "$WIREGUARD_PEER" ]; then
        rm -f $WIREGUARD_PATH
      fi
      mkdir -p $WIREGUARD_PATH
      echo "WireGuard Interface: true" >>$WIREGUARD_INTERFACE
      ;;
    2)
      if [ -f "$WIREGUARD_INTERFACE" ]; then
        rm -f $WIREGUARD_PATH
      fi
      mkdir -p $WIREGUARD_PATH
      echo "WireGuard Peer: true" >>$WIREGUARD_PEER
      ;;
    esac
  fi
}

# Interface or Peer
interface-or-peer

# Usage Guide
function usage-guide() {
  if [ -f "$WIREGUARD_INTERFACE" ]; then
    echo "usage: ./$(basename "$0") <command>"
    echo "  --install     Install WireGuard Interface"
    echo "  --start       Start WireGuard Interface"
    echo "  --stop        Stop WireGuard Interface"
    echo "  --restart     Restart WireGuard Interface"
    echo "  --list        Show WireGuard Peers"
    echo "  --add         Add WireGuard Peer"
    echo "  --remove      Remove WireGuard Peer"
    echo "  --reinstall   Reinstall WireGuard Interface"
    echo "  --uninstall   Uninstall WireGuard Interface"
    echo "  --update      Update WireGuard Script"
    echo "  --backup      Backup WireGuard Configs"
    echo "  --restore     Restore WireGuard Configs"
    echo "  --help        Show Usage Guide"
    exit
  fi
}

# The usage of the script
function usage() {
  if [ -f "$WIREGUARD_INTERFACE" ]; then
    while [ $# -ne 0 ]; do
      case "${1}" in
      --install)
        shift
        HEADLESS_INSTALL=${HEADLESS_INSTALL:-y}
        ;;
      --start)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-2}
        ;;
      --stop)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-3}
        ;;
      --restart)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-4}
        ;;
      --list)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-1}
        ;;
      --add)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-5}
        ;;
      --remove)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-6}
        ;;
      --reinstall)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-7}
        ;;
      --uninstall)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-8}
        ;;
      --update)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-9}
        ;;
      --backup)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-10}
        ;;
      --restore)
        shift
        WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-11}
        ;;
      --help)
        shift
        usage-guide
        ;;
      *)
        echo "Invalid argument: $1"
        usage-guide
        exit
        ;;
      esac
      shift
    done
  fi
}

usage "$@"

# Skips all questions and just get a client conf after install.
function headless-install() {
  if [ "$HEADLESS_INSTALL" == "y" ]; then
      INTERFACE_OR_PEER=${INTERFACE_OR_PEER:-1}
      IPV4_SUBNET_SETTINGS=${IPV4_SUBNET_SETTINGS:-1}
      IPV6_SUBNET_SETTINGS=${IPV6_SUBNET_SETTINGS:-1}
      SERVER_HOST_V4_SETTINGS=${SERVER_HOST_V4_SETTINGS:-1}
      SERVER_HOST_V6_SETTINGS=${SERVER_HOST_V6_SETTINGS:-1}
      SERVER_PUB_NIC_SETTINGS=${SERVER_PUB_NIC_SETTINGS:-1}
      SERVER_PORT_SETTINGS=${SERVER_PORT_SETTINGS:-1}
      NAT_CHOICE_SETTINGS=${NAT_CHOICE_SETTINGS:-1}
      MTU_CHOICE_SETTINGS=${MTU_CHOICE_SETTINGS:-1}
      SERVER_HOST_SETTINGS=${SERVER_HOST_SETTINGS:-1}
      DISABLE_HOST_SETTINGS=${DISABLE_HOST_SETTINGS:-1}
      CLIENT_ALLOWED_IP_SETTINGS=${CLIENT_ALLOWED_IP_SETTINGS:-1}
      DNS_PROVIDER_SETTINGS=${DNS_PROVIDER_SETTINGS:-1}
      CLIENT_NAME=${CLIENT_NAME:-client}
  fi
}

# No GUI
headless-install

if [ ! -f "$WIREGUARD_CONFIG" ]; then

  # Custom ipv4 subnet
  function set-ipv4-subnet() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What ipv4 subnet do you want to use?"
      echo "  1) 10.8.0.0/24 (Recommended)"
      echo "  2) 10.0.0.0/24"
      echo "  3) Custom (Advanced)"
      until [[ "$IPV4_SUBNET_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "Subnetwork Choice [1-3]: " -e -i 1 IPV4_SUBNET_SETTINGS
      done
      case $IPV4_SUBNET_SETTINGS in
      1)
        IPV4_SUBNET="10.8.0.0/24"
        ;;
      2)
        IPV4_SUBNET="10.0.0.0/24"
        ;;
      3)
        read -rp "Custom Subnet: " -e -i "10.8.0.0/24" IPV4_SUBNET
        ;;
      esac
    fi
  }

  # Custom ipv4 Subnet
  set-ipv4-subnet

  # Custom ipv6 subnet
  function set-ipv6-subnet() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What ipv6 subnet do you want to use?"
      echo "  1) fd42:42:42::0/64 (Recommended)"
      echo "  2) fd86:ea04:1115::0/64"
      echo "  3) Custom (Advanced)"
      until [[ "$IPV6_SUBNET_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "Subnetwork Choice [1-3]: " -e -i 1 IPV6_SUBNET_SETTINGS
      done
      case $IPV6_SUBNET_SETTINGS in
      1)
        IPV6_SUBNET="fd42:42:42::0/64"
        ;;
      2)
        IPV6_SUBNET="fd86:ea04:1115::0/64"
        ;;
      3)
        read -rp "Custom Subnet: " -e -i "fd42:42:42::0/64" IPV6_SUBNET
        ;;
      esac
    fi
  }

  # Custom ipv6 Subnet
  set-ipv6-subnet

  # Private Subnet Ipv4
  PRIVATE_SUBNET_V4=${PRIVATE_SUBNET_V4:-"$IPV4_SUBNET"}
  # Private Subnet Mask IPv4
  PRIVATE_SUBNET_MASK_V4=$(echo "$PRIVATE_SUBNET_V4" | cut -d "/" -f 2)
  # IPv4 Getaway
  GATEWAY_ADDRESS_V4="${PRIVATE_SUBNET_V4::-4}1"
  # Private Subnet Ipv6
  PRIVATE_SUBNET_V6=${PRIVATE_SUBNET_V6:-"$IPV6_SUBNET"}
  # Private Subnet Mask IPv6
  PRIVATE_SUBNET_MASK_V6=$(echo "$PRIVATE_SUBNET_V6" | cut -d "/" -f 2)
  # IPv6 Getaway
  GATEWAY_ADDRESS_V6="${PRIVATE_SUBNET_V6::-4}1"

  # Get the IPV4
  function test-connectivity-v4() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "How would you like to detect IPv4?"
      echo "  1) Curl (Recommended)"
      echo "  2) IP (Advanced)"
      echo "  3) Custom (Advanced)"
      until [[ "$SERVER_HOST_V4_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "IPv4 Choice [1-3]: " -e -i 1 SERVER_HOST_V4_SETTINGS
      done
      case $SERVER_HOST_V4_SETTINGS in
      1)
        SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
        ;;
      2)
        SERVER_HOST_V4="$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)"
        ;;
      3)
        read -rp "Custom IPv4: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V4
        ;;
      esac
    fi
  }

  # Get the IPV4
  test-connectivity-v4

  # Determine ipv6
  function test-connectivity-v6() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "How would you like to detect IPv6?"
      echo "  1) Curl (Recommended)"
      echo "  2) IP (Advanced)"
      echo "  3) Custom (Advanced)"
      until [[ "$SERVER_HOST_V6_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "IPv6 Choice [1-3]: " -e -i 1 SERVER_HOST_V6_SETTINGS
      done
      case $SERVER_HOST_V6_SETTINGS in
      1)
        SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
        ;;
      2)
        SERVER_HOST_V6="$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)"
        ;;
      3)
        read -rp "Custom IPv6: " -e -i "$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')" SERVER_HOST_V6
        ;;
      esac
    fi
  }

  # Get the IPV6
  test-connectivity-v6

  # Determine public nic
  function server-pub-nic() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "How would you like to detect NIC?"
      echo "  1) IP (Recommended)"
      echo "  2) Custom (Advanced)"
      until [[ "$SERVER_PUB_NIC_SETTINGS" =~ ^[1-2]$ ]]; do
        read -rp "nic Choice [1-2]: " -e -i 1 SERVER_PUB_NIC_SETTINGS
      done
      case $SERVER_PUB_NIC_SETTINGS in
      1)
        SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
        ;;
      2)
        read -rp "Custom NAT: " -e -i "$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)" SERVER_PUB_NIC
        ;;
      esac
    fi
  }

  # Determine public nic
  server-pub-nic

  # Determine host port
  function set-port() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What port do you want WireGuard server to listen to?"
      echo "  1) 51820 (Recommended)"
      echo "  2) Custom (Advanced)"
      echo "  3) Random [1024-65535]"
      until [[ "$SERVER_PORT_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "Port Choice [1-3]: " -e -i 1 SERVER_PORT_SETTINGS
      done
      case $SERVER_PORT_SETTINGS in
      1)
        SERVER_PORT="51820"
        ;;
      2)
        until [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [ "$SERVER_PORT" -ge 1024 ] && [ "$SERVER_PORT" -le 65535 ]; do
          read -rp "Custom port [1024-65535]: " -e -i 51820 SERVER_PORT
        done
        ;;
      3)
        SERVER_PORT=$(shuf -i1024-65535 -n1)
        echo "Random Port: $SERVER_PORT"
        ;;
      esac
    fi
  }

  # Set Port
  set-port

  # Determine Keepalive interval.
  function nat-keepalive() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What do you want your keepalive interval to be?"
      echo "  1) 25 (Default)"
      echo "  2) Custom (Advanced)"
      echo "  3) Random [1-25]"
      until [[ "$NAT_CHOICE_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "Nat Choice [1-3]: " -e -i 1 NAT_CHOICE_SETTINGS
      done
      case $NAT_CHOICE_SETTINGS in
      1)
        NAT_CHOICE="25"
        ;;
      2)
        until [[ "$NAT_CHOICE" =~ ^[0-9]+$ ]] && [ "$NAT_CHOICE" -ge 0 ] && [ "$NAT_CHOICE" -le 25 ]; do
          read -rp "Custom NAT [0-25]: " -e -i 25 NAT_CHOICE
        done
        ;;
      3)
        NAT_CHOICE=$(shuf -i1-25 -n1)
        ;;
      esac
    fi
  }

  # Keepalive
  nat-keepalive

  # Custom MTU or default settings
  function mtu-set() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What MTU do you want to use?"
      echo "  1) 1280 (Recommended)"
      echo "  2) 1420"
      echo "  3) Custom (Advanced)"
      until [[ "$MTU_CHOICE_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "MTU Choice [1-3]: " -e -i 1 MTU_CHOICE_SETTINGS
      done
      case $MTU_CHOICE_SETTINGS in
      1)
        MTU_CHOICE="1280"
        ;;
      2)
        MTU_CHOICE="1420"
        ;;
      3)
        until [[ "$MTU_CHOICE" =~ ^[0-9]+$ ]] && [ "$MTU_CHOICE" -ge 0 ] && [ "$MTU_CHOICE" -le 1500 ]; do
          read -rp "Custom MTU [0-1500]: " -e -i 1280 MTU_CHOICE
        done
        ;;
      esac
    fi
  }

  # Set MTU
  mtu-set

  # What ip version would you like to be available on this VPN?
  function ipvx-select() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What IPv do you want to use to connect to WireGuard server?"
      echo "  1) IPv4 (Recommended)"
      echo "  2) IPv6"
      echo "  3) Custom (Advanced)"
      until [[ "$SERVER_HOST_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "IP Choice [1-3]: " -e -i 1 SERVER_HOST_SETTINGS
      done
      case $SERVER_HOST_SETTINGS in
      1)
        SERVER_HOST="$SERVER_HOST_V4"
        ;;
      2)
        SERVER_HOST="[$SERVER_HOST_V6]"
        ;;
      3)
        read -rp "Custom Domain: " -e -i "$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.hostname')" SERVER_HOST
        ;;
      esac
    fi
  }

  # IPv4 or IPv6 Selector
  ipvx-select

  # Do you want to disable IPv4 or IPv6 or leave them both enabled?
  function disable-ipvx() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "Do you want to disable IPv4 or IPv6 on the server?"
      echo "  1) No (Recommended)"
      echo "  2) Disable IPV4"
      echo "  3) Disable IPV6"
      until [[ "$DISABLE_HOST_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "Disable Host Choice [1-3]: " -e -i 1 DISABLE_HOST_SETTINGS
      done
      case $DISABLE_HOST_SETTINGS in
      1)
        if [ ! -f "/etc/sysctl.d/wireguard.conf" ]; then
          echo "net.ipv4.ip_forward=1" >>/etc/sysctl.d/wireguard.conf
          echo "net.ipv6.conf.all.forwarding=1" >>/etc/sysctl.d/wireguard.conf
          sysctl -p /etc/sysctl.d/wireguard.conf
        fi
        ;;
      2)
        if [ ! -f "/etc/sysctl.d/wireguard.conf" ]; then
          echo "net.ipv6.conf.all.forwarding=1" >>/etc/sysctl.d/wireguard.conf
          sysctl -p /etc/sysctl.d/wireguard.conf
        fi
        ;;
      3)
        if [ ! -f "/etc/sysctl.d/wireguard.conf" ]; then
          echo "net.ipv4.ip_forward=1" >>/etc/sysctl.d/wireguard.conf
          sysctl -p /etc/sysctl.d/wireguard.conf
        fi
        ;;
      esac
    fi
  }

  # Disable Ipv4 or Ipv6
  disable-ipvx

  # Would you like to allow connections to your LAN neighbors?
  function client-allowed-ip() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What traffic do you want the client to forward to wireguard?"
      echo "  1) Everything (Recommended)"
      echo "  2) Exclude Private IPs"
      echo "  3) Custom (Advanced)"
      until [[ "$CLIENT_ALLOWED_IP_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "Client Allowed IP Choice [1-3]: " -e -i 1 CLIENT_ALLOWED_IP_SETTINGS
      done
      case $CLIENT_ALLOWED_IP_SETTINGS in
      1)
        CLIENT_ALLOWED_IP="0.0.0.0/0,::/0"
        ;;
      2)
        CLIENT_ALLOWED_IP="0.0.0.0/5,8.0.0.0/7,11.0.0.0/8,12.0.0.0/6,16.0.0.0/4,32.0.0.0/3,64.0.0.0/2,128.0.0.0/3,160.0.0.0/5,168.0.0.0/6,172.0.0.0/12,172.32.0.0/11,172.64.0.0/10,172.128.0.0/9,173.0.0.0/8,174.0.0.0/7,176.0.0.0/4,192.0.0.0/9,192.128.0.0/11,192.160.0.0/13,192.169.0.0/16,192.170.0.0/15,192.172.0.0/14,192.176.0.0/12,192.192.0.0/10,193.0.0.0/8,194.0.0.0/7,196.0.0.0/6,200.0.0.0/5,208.0.0.0/4"
        ;;
      3)
        read -rp "Custom IPs: " -e -i "0.0.0.0/0,::/0" CLIENT_ALLOWED_IP
        ;;
      esac
    fi
  }

  # Traffic Forwarding
  client-allowed-ip

  # Would you like to install Unbound.
  function ask-install-dns() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "Which DNS provider would you like to use?"
      echo "  1) Unbound (Recommended)"
      echo "  2) PiHole"
      echo "  3) Custom (Advanced)"
      until [[ "$DNS_PROVIDER_SETTINGS" =~ ^[1-3]$ ]]; do
        read -rp "DNS provider [1-3]: " -e -i 1 DNS_PROVIDER_SETTINGS
      done
      case $DNS_PROVIDER_SETTINGS in
      1)
        INSTALL_UNBOUND="y"
        ;;
      2)
        INSTALL_PIHOLE="y"
        ;;
      3)
        CUSTOM_DNS="y"
        ;;
      esac
    fi
  }

  # Ask To Install DNS
  ask-install-dns

  # What would you like to name your first WireGuard peer?
  function client-name() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      if [ "$CLIENT_NAME" == "" ]; then
        echo "Lets name the WireGuard Peer, Use one word only, no special characters. (No Spaces)"
        read -rp "Client name: " -e CLIENT_NAME
      fi
    fi
  }

  # Client Name
  client-name

  # Lets check the kernel version and check if headers are required
  function install-kernel-headers() {
    KERNEL_VERSION_LIMIT=5.6
    KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
    if (($(echo "$KERNEL_CURRENT_VERSION <= $KERNEL_VERSION_LIMIT" | bc -l))); then
      if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
        apt-get update
        apt-get install linux-headers-"$(uname -r)" -y
      elif [ "$DISTRO" == "raspbian" ]; then
        apt-get update
        apt-get install raspberrypi-kernel-headers -y
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Syu
        pacman -Syu --noconfirm linux-headers
      elif [ "$DISTRO" == "fedora" ]; then
        dnf update -y
        dnf install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)" -y
      elif { [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
        yum update -y
        yum install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)" -y
      fi
    else
      echo "Correct: You do not need kernel headers." >/dev/null 2>&1
    fi
  }

  # Kernel Version
  install-kernel-headers

  # Install WireGuard Server
  function install-wireguard-server() {
    if ! [ -x "$(command -v wg)" ]; then
      if [ "$DISTRO" == "ubuntu" ] && { [ "$DISTRO_VERSION" == "20.10" ] || [ "$DISTRO_VERSION" == "20.04" ] || [ "$DISTRO_VERSION" == "19.10" ]; }; then
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif [ "$DISTRO" == "ubuntu" ] && { [ "$DISTRO_VERSION" == "16.04" ] || [ "$DISTRO_VERSION" == "18.04" ]; }; then
        apt-get update
        apt-get install software-properties-common -y
        add-apt-repository ppa:wireguard/wireguard -y
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif [ "$DISTRO" == "pop" ]; then
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "kali" ]; }; then
        apt-get update
        if [ ! -f "/etc/apt/sources.list.d/unstable.list" ]; then
          echo "deb http://deb.debian.org/debian/ unstable main" >>/etc/apt/sources.list.d/unstable.list
        fi
        if [ ! -f "/etc/apt/preferences.d/limit-unstable" ]; then
          printf "Package: *\nPin: release a=unstable\nPin-Priority: 90\n" >>/etc/apt/preferences.d/limit-unstable
        fi
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif [ "$DISTRO" == "raspbian" ]; then
        apt-get update
        apt-get install dirmngr -y
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
        if [ ! -f "/etc/apt/sources.list.d/unstable.list" ]; then
          echo "deb http://deb.debian.org/debian/ unstable main" >>/etc/apt/sources.list.d/unstable.list
        fi
        if [ ! -f "/etc/apt/preferences.d/limit-unstable" ]; then
          printf "Package: *\nPin: release a=unstable\nPin-Priority: 90\n" >>/etc/apt/preferences.d/limit-unstable
        fi
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Syu
        pacman -Syu --noconfirm haveged qrencode iptables resolvconf
        pacman -Syu --noconfirm wireguard-tools
      elif [ "$DISTRO" = "fedora" ] && [ "$DISTRO_VERSION" == "32" ]; then
        dnf update -y
        dnf install qrencode wireguard-tools haveged resolvconf -y
      elif [ "$DISTRO" = "fedora" ] && { [ "$DISTRO_VERSION" == "30" ] || [ "$DISTRO_VERSION" == "31" ]; }; then
        dnf update -y
        dnf copr enable jdoss/wireguard -y
        dnf install qrencode wireguard-dkms wireguard-tools haveged resolvconf -y
      elif [ "$DISTRO" == "centos" ] && { [ "$DISTRO_VERSION" == "8" ] || [ "$DISTRO_VERSION" == "8.1" ]; }; then
        yum update -y
        yum config-manager --set-enabled PowerTools
        yum copr enable jdoss/wireguard -y
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "centos" ] && [ "$DISTRO_VERSION" == "7" ]; then
        yum update -y
        if [ ! -f "/etc/yum.repos.d/wireguard.repo" ]; then
          curl https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo --create-dirs -o /etc/yum.repos.d/wireguard.repo
        fi
        yum update -y
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "rhel" ] && [ "$DISTRO_VERSION" == "8" ]; then
        yum update -y
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        yum update -y
        subscription-manager repos --enable codeready-builder-for-rhel-8-"$(arch)"-rpms
        yum copr enable jdoss/wireguard
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "rhel" ] && [ "$DISTRO_VERSION" == "7" ]; then
        yum update -y
        if [ ! -f "/etc/yum.repos.d/wireguard.repo" ]; then
          curl https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo --create-dirs -o /etc/yum.repos.d/wireguard.repo
        fi
        yum update -y
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "alpine" ]; then
        apk update
        apk add wireguard-tools libqrencode haveged
      fi
    fi
  }

  # Install WireGuard Server
  install-wireguard-server

  # Install wireguard manager config
  function install-wireguard-manager-file() {
    if [ ! -f "$WIREGUARD_MANAGER" ]; then
      echo "WireGuard: true" >>$WIREGUARD_MANAGER
    fi
  }

  # wireguard manager config
  install-wireguard-manager-file

  # Function to install unbound
  function install-unbound() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      if [ "$INSTALL_UNBOUND" = "y" ]; then
        if ! [ -x "$(command -v unbound)" ]; then
          if [ "$DISTRO" == "ubuntu" ]; then
            apt-get install unbound unbound-host e2fsprogs -y
            if pgrep systemd-journal; then
              systemctl stop systemd-resolved
              systemctl disable systemd-resolved
            else
              service systemd-resolved stop
              service systemd-resolved disable
            fi
          elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
            apt-get install unbound unbound-host e2fsprogs -y
          elif { [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
            yum install unbound unbound-libs -y
          elif [ "$DISTRO" == "fedora" ]; then
            dnf install unbound -y
          elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
            pacman -Syu --noconfirm unbound
          elif [ "$DISTRO" == "alpine" ]; then
            apk add unbound
          fi
          unbound-anchor -a /var/lib/unbound/root.key
          rm -f /etc/unbound/unbound.conf
          NPROC=$(nproc)
          echo "server:
    num-threads: $NPROC
    verbosity: 1
    root-hints: /etc/unbound/root.hints
    auto-trust-anchor-file: /var/lib/unbound/root.key
    interface: 0.0.0.0
    interface: ::0
    max-udp-size: 3072
    access-control: 0.0.0.0/0                 refuse
    access-control: ::0                       refuse
    access-control: $PRIVATE_SUBNET_V4               allow
    access-control: $PRIVATE_SUBNET_V6          allow
    access-control: 127.0.0.1                 allow
    private-address: $PRIVATE_SUBNET_V4
    private-address: $PRIVATE_SUBNET_V6
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    unwanted-reply-threshold: 10000000
    val-log-level: 1
    cache-min-ttl: 1800
    cache-max-ttl: 14400
    prefetch: yes
    qname-minimisation: yes
    prefetch-key: yes" >>/etc/unbound/unbound.conf
          # Set DNS Root Servers
          curl https://www.internic.net/domain/named.cache --create-dirs -o /etc/unbound/root.hints
          chattr -i /etc/resolv.conf
          mv /etc/resolv.conf /etc/resolv.conf.old
          echo "nameserver 127.0.0.1" >>/etc/resolv.conf
          echo "nameserver ::1" >>/etc/resolv.conf
          chattr +i /etc/resolv.conf
          echo "Unbound: true" >>/etc/unbound/wireguard-manager
          # restart unbound
          if pgrep systemd-journal; then
            systemctl enable unbound
            systemctl restart unbound
          else
            service unbound enable
            service unbound restart
          fi
        fi
        CLIENT_DNS="$GATEWAY_ADDRESS_V4,$GATEWAY_ADDRESS_V6"
      fi
    fi
  }

  # Running Install Unbound
  install-unbound

  # Install pihole
  function install-pihole() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      if [ "$INSTALL_PIHOLE" = "y" ]; then
        if ! [ -x "$(command -v pihole)" ]; then
          curl -sSL https://install.pi-hole.net | bash
          echo "PiHole: true" >>/etc/pihole/wireguard-manager
        fi
        CLIENT_DNS="$GATEWAY_ADDRESS_V4,$GATEWAY_ADDRESS_V6"
      fi
    fi
  }

  # install pihole
  install-pihole

  # Use custom dns
  function custom-dns() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      if [ "$CUSTOM_DNS" == "y" ]; then
        echo "Which DNS do you want to use with the VPN?"
        echo "  1) Google (Recommended)"
        echo "  2) AdGuard"
        echo "  3) NextDNS"
        echo "  4) OpenDNS"
        echo "  5) Cloudflare"
        echo "  6) Verisign"
        echo "  7) Quad9"
        echo "  8) FDN"
        echo "  9) Custom (Advanced)"
        until [[ "$CLIENT_DNS_SETTINGS" =~ ^[0-9]+$ ]] && [ "$CLIENT_DNS_SETTINGS" -ge 1 ] && [ "$CLIENT_DNS_SETTINGS" -le 9 ]; do
          read -rp "DNS [1-9]: " -e -i 1 CLIENT_DNS_SETTINGS
        done
        case $CLIENT_DNS_SETTINGS in
        1)
          CLIENT_DNS="8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844"
          ;;
        2)
          CLIENT_DNS="176.103.130.130,176.103.130.131,2a00:5a60::ad1:0ff,2a00:5a60::ad2:0ff"
          ;;
        3)
          CLIENT_DNS="45.90.28.167,45.90.30.167,2a07:a8c0::12:cf53,2a07:a8c1::12:cf53"
          ;;
        4)
          CLIENT_DNS="208.67.222.222,208.67.220.220,2620:119:35::35,2620:119:53::53"
          ;;
        5)
          CLIENT_DNS="1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001"
          ;;
        6)
          CLIENT_DNS="64.6.64.6,64.6.65.6,2620:74:1b::1:1,2620:74:1c::2:2"
          ;;
        7)
          CLIENT_DNS="9.9.9.9,149.112.112.112,2620:fe::fe,2620:fe::9"
          ;;
        8)
          CLIENT_DNS="80.67.169.40,80.67.169.12,2001:910:800::40,2001:910:800::12"
          ;;
        9)
          read -rp "Custom DNS (IPv4 IPv6):" -e -i "8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844" CLIENT_DNS
          ;;
        esac
      fi
    fi
  }

  # use custom dns
  custom-dns

  # WireGuard Set Config
  function wireguard-setconf() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      SERVER_PRIVKEY=$(wg genkey)
      SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)
      CLIENT_PRIVKEY=$(wg genkey)
      CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)
      CLIENT_ADDRESS_V4="${PRIVATE_SUBNET_V4::-4}3"
      CLIENT_ADDRESS_V6="${PRIVATE_SUBNET_V6::-4}3"
      PRESHARED_KEY=$(wg genpsk)
      PEER_PORT=$(shuf -i1024-65535 -n1)
      mkdir -p /etc/wireguard/clients
      touch $WIREGUARD_CONFIG && chmod 600 $WIREGUARD_CONFIG
      # Set Wireguard settings for this host and first peer.
      echo "# $PRIVATE_SUBNET_V4 $PRIVATE_SUBNET_V6 $SERVER_HOST:$SERVER_PORT $SERVER_PUBKEY $CLIENT_DNS $MTU_CHOICE $NAT_CHOICE $CLIENT_ALLOWED_IP
[Interface]
Address = $GATEWAY_ADDRESS_V4/$PRIVATE_SUBNET_MASK_V4,$GATEWAY_ADDRESS_V6/$PRIVATE_SUBNET_MASK_V6
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIVKEY
PostUp = iptables -A FORWARD -i $WIREGUARD_PUB_NIC -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -A FORWARD -i $WIREGUARD_PUB_NIC -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; iptables -A INPUT -s $PRIVATE_SUBNET_V4 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT; ip6tables -A INPUT -s $PRIVATE_SUBNET_V6 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
PostDown = iptables -D FORWARD -i $WIREGUARD_PUB_NIC -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; ip6tables -D FORWARD -i $WIREGUARD_PUB_NIC -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE; iptables -D INPUT -s $PRIVATE_SUBNET_V4 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT; ip6tables -D INPUT -s $PRIVATE_SUBNET_V6 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
SaveConfig = false
# $CLIENT_NAME start
[Peer]
PublicKey = $CLIENT_PUBKEY
PresharedKey = $PRESHARED_KEY
AllowedIPs = $CLIENT_ADDRESS_V4/32,$CLIENT_ADDRESS_V6/128
# $CLIENT_NAME end" >>$WIREGUARD_CONFIG

      echo "# $CLIENT_NAME
[Interface]
Address = $CLIENT_ADDRESS_V4/$PRIVATE_SUBNET_MASK_V4,$CLIENT_ADDRESS_V6/$PRIVATE_SUBNET_MASK_V6
DNS = $CLIENT_DNS
ListenPort = $PEER_PORT
MTU = $MTU_CHOICE
PrivateKey = $CLIENT_PRIVKEY
[Peer]
AllowedIPs = $CLIENT_ALLOWED_IP
Endpoint = $SERVER_HOST:$SERVER_PORT
PersistentKeepalive = $NAT_CHOICE
PresharedKey = $PRESHARED_KEY
PublicKey = $SERVER_PUBKEY" >>/etc/wireguard/clients/"$CLIENT_NAME"-$WIREGUARD_PUB_NIC.conf
      # Service Restart
      if pgrep systemd-journal; then
        systemctl enable wg-quick@$WIREGUARD_PUB_NIC
        systemctl restart wg-quick@$WIREGUARD_PUB_NIC
      else
        service wg-quick@$WIREGUARD_PUB_NIC enable
        service wg-quick@$WIREGUARD_PUB_NIC restart
      fi
      # Generate QR Code
      qrencode -t ansiutf8 -l L </etc/wireguard/clients/"$CLIENT_NAME"-$WIREGUARD_PUB_NIC.conf
      echo "Client Config --> /etc/wireguard/clients/$CLIENT_NAME-$WIREGUARD_PUB_NIC.conf"
    fi
  }

  # Setting Up Wireguard Config
  wireguard-setconf

# After WireGuard Install
else

  # Already installed what next?
  function wireguard-next-questions() {
    if [ -f "$WIREGUARD_INTERFACE" ]; then
      echo "What do you want to do?"
      echo "   1) Show WireGuard Interface"
      echo "   2) Start WireGuard Interface"
      echo "   3) Stop WireGuard Interface"
      echo "   4) Restart WireGuard Interface"
      echo "   5) Add WireGuard Peer"
      echo "   6) Remove WireGuard Peer"
      echo "   7) Reinstall WireGuard Interface"
      echo "   8) Uninstall WireGuard Interface"
      echo "   9) Update this script"
      echo "   10) Backup WireGuard Config"
      echo "   11) Restore WireGuard Config"
      until [[ "$WIREGUARD_OPTIONS" =~ ^[0-9]+$ ]] && [ "$WIREGUARD_OPTIONS" -ge 1 ] && [ "$WIREGUARD_OPTIONS" -le 11 ]; do
        read -rp "Select an Option [1-11]: " -e -i 1 WIREGUARD_OPTIONS
      done
      case $WIREGUARD_OPTIONS in
      1) # WG Show
        wg show
        ;;
      2) # Enable & Start Wireguard
        if pgrep systemd-journal; then
          systemctl enable wg-quick@$WIREGUARD_PUB_NIC
          systemctl start wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC enable
          service wg-quick@$WIREGUARD_PUB_NIC start
        fi
        ;;
      3) # Disable & Stop WireGuard
        if pgrep systemd-journal; then
          systemctl disable wg-quick@$WIREGUARD_PUB_NIC
          systemctl stop wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC disable
          service wg-quick@$WIREGUARD_PUB_NIC stop
        fi
        ;;
      4) # Restart WireGuard
        if pgrep systemd-journal; then
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC restart
        fi
        ;;
      5) # WireGuard add Peer
        if [ "$NEW_CLIENT_NAME" == "" ]; then
          echo "Lets name the WireGuard Peer, Use one word only, no special characters. (No Spaces)"
          read -rp "New client peer: " -e NEW_CLIENT_NAME
        fi
        CLIENT_PRIVKEY=$(wg genkey)
        CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)
        PRESHARED_KEY=$(wg genpsk)
        PEER_PORT=$(shuf -i1024-65535 -n1)
        PRIVATE_SUBNET_V4=$(head -n1 $WIREGUARD_CONFIG | awk '{print $2}')
        PRIVATE_SUBNET_MASK_V4=$(echo "$PRIVATE_SUBNET_V4" | cut -d "/" -f 2)
        PRIVATE_SUBNET_V6=$(head -n1 $WIREGUARD_CONFIG | awk '{print $3}')
        PRIVATE_SUBNET_MASK_V6=$(echo "$PRIVATE_SUBNET_V6" | cut -d "/" -f 2)
        SERVER_HOST=$(head -n1 $WIREGUARD_CONFIG | awk '{print $4}')
        SERVER_PUBKEY=$(head -n1 $WIREGUARD_CONFIG | awk '{print $5}')
        CLIENT_DNS=$(head -n1 $WIREGUARD_CONFIG | awk '{print $6}')
        MTU_CHOICE=$(head -n1 $WIREGUARD_CONFIG | awk '{print $7}')
        NAT_CHOICE=$(head -n1 $WIREGUARD_CONFIG | awk '{print $8}')
        CLIENT_ALLOWED_IP=$(head -n1 $WIREGUARD_CONFIG | awk '{print $9}')
        LASTIP4=$(grep "/32" $WIREGUARD_CONFIG | tail -n1 | awk '{print $3}' | cut -d "/" -f 1 | cut -d "." -f 4)
        LASTIP6=$(grep "/128" $WIREGUARD_CONFIG | tail -n1 | awk '{print $3}' | cut -d "/" -f 1 | cut -d "." -f 4)
        CLIENT_ADDRESS_V4="${PRIVATE_SUBNET_V4::-4}$((LASTIP4 + 1))"
        CLIENT_ADDRESS_V6="${PRIVATE_SUBNET_V6::-4}$((LASTIP6 + 1))"
        echo "# $NEW_CLIENT_NAME start
[Peer]
PublicKey = $CLIENT_PUBKEY
PresharedKey = $PRESHARED_KEY
AllowedIPs = $CLIENT_ADDRESS_V4/32,$CLIENT_ADDRESS_V6/128
# $NEW_CLIENT_NAME end" >>$WIREGUARD_CONFIG
        echo "# $NEW_CLIENT_NAME
[Interface]
Address = $CLIENT_ADDRESS_V4/$PRIVATE_SUBNET_MASK_V4,$CLIENT_ADDRESS_V6/$PRIVATE_SUBNET_MASK_V6
DNS = $CLIENT_DNS
ListenPort = $PEER_PORT
MTU = $MTU_CHOICE
PrivateKey = $CLIENT_PRIVKEY
[Peer]
AllowedIPs = $CLIENT_ALLOWED_IP
Endpoint = $SERVER_HOST$SERVER_PORT
PersistentKeepalive = $NAT_CHOICE
PresharedKey = $PRESHARED_KEY
PublicKey = $SERVER_PUBKEY" >>/etc/wireguard/clients/"$NEW_CLIENT_NAME"-$WIREGUARD_PUB_NIC.conf
        qrencode -t ansiutf8 -l L </etc/wireguard/clients/"$NEW_CLIENT_NAME"-$WIREGUARD_PUB_NIC.conf
        echo "Client config --> /etc/wireguard/clients/$NEW_CLIENT_NAME-$WIREGUARD_PUB_NIC.conf"
        # Restart WireGuard
        if pgrep systemd-journal; then
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC restart
        fi
        ;;
      6) # Remove WireGuard Peer
        echo "Which WireGuard user do you want to remove?"
        # shellcheck disable=SC2002
        cat $WIREGUARD_CONFIG | grep start | awk '{ print $2 }'
        read -rp "Type in Client Name : " -e REMOVECLIENT
        read -rp "Are you sure you want to remove $REMOVECLIENT ? (y/n): " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          sed -i "/\# $REMOVECLIENT start/,/\# $REMOVECLIENT end/d" $WIREGUARD_CONFIG
          rm -f /etc/wireguard/clients/"$REMOVECLIENT"-$WIREGUARD_PUB_NIC.conf
          echo "Client $REMOVECLIENT has been removed."
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
          exit
        fi
        # Restart WireGuard
        if pgrep systemd-journal; then
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC restart
        fi
        ;;
      7) # Reinstall Wireguard
        if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
          dpkg-reconfigure wireguard-dkms
          modprobe wireguard
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
          yum reinstall wireguard-dkms -y
          service wg-quick@$WIREGUARD_PUB_NIC restart
        elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
          pacman -Rs --noconfirm wireguard-tools
          service wg-quick@$WIREGUARD_PUB_NIC restart
        elif [ "$DISTRO" == "alpine" ]; then
          apk fix wireguard-tools
        fi
        ;;
      8) # Uninstall Wireguard and purging files
        if [ -f "$WIREGUARD_MANAGER" ]; then
          if pgrep systemd-journal; then
            systemctl disable wg-quick@$WIREGUARD_PUB_NIC
            wg-quick down $WIREGUARD_PUB_NIC
          else
            service wg-quick@$WIREGUARD_PUB_NIC disable
            wg-quick down $WIREGUARD_PUB_NIC
          fi
          # Removing Wireguard Files
          rm -rf /etc/wireguard
          rm -rf /etc/wireguard/clients
          rm -f /etc/wireguard/$WIREGUARD_PUB_NIC.conf
          rm -f /etc/sysctl.d/wireguard.conf
          if [ "$DISTRO" == "centos" ]; then
            yum remove wireguard qrencode haveged -y
          elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "kali" ]; }; then
            apt-get remove --purge wireguard qrencode -y
            rm -f /etc/apt/sources.list.d/unstable.list
            rm -f /etc/apt/preferences.d/limit-unstable
          elif [ "$DISTRO" == "pop" ]; then
            apt-get remove --purge wireguard qrencode haveged -y
          elif [ "$DISTRO" == "ubuntu" ]; then
            apt-get remove --purge wireguard qrencode haveged -y
            if pgrep systemd-journal; then
              systemctl enable systemd-resolved
              systemctl restart systemd-resolved
            else
              service systemd-resolved enable
              service systemd-resolved restart
            fi
          elif [ "$DISTRO" == "raspbian" ]; then
            apt-key del 04EE7237B7D453EC
            apt-get remove --purge wireguard qrencode haveged dirmngr -y
            rm -f /etc/apt/sources.list.d/unstable.list
            rm -f /etc/apt/preferences.d/limit-unstable
          elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
            pacman -Rs wireguard qrencode haveged -y
          elif [ "$DISTRO" == "fedora" ]; then
            dnf remove wireguard qrencode haveged -y
            rm -f /etc/yum.repos.d/wireguard.repo
          elif [ "$DISTRO" == "rhel" ]; then
            yum remove wireguard qrencode haveged -y
            rm -f /etc/yum.repos.d/wireguard.repo
          elif [ "$DISTRO" == "alpine" ]; then
            apk del wireguard-tools libqrencode haveged
          fi
        fi
        # Uninstall Unbound
        if [ -f "/etc/unbound/wireguard-manager" ]; then
          if pgrep systemd-journal; then
            systemctl disable unbound
            systemctl stop unbound
          else
            service unbound disable
            service unbound stop
          fi
          # Change to defualt dns
          chattr -i /etc/resolv.conf
          rm -f /etc/resolv.conf
          mv /etc/resolv.conf.old /etc/resolv.conf
          chattr +i /etc/resolv.conf
          if { [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
            yum remove unbound unbound-host -y
          elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "kali" ]; }; then
            apt-get remove --purge unbound unbound-host -y
          elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
            pacman -Rs unbound unbound-host -y
          elif [ "$DISTRO" == "fedora" ]; then
            dnf remove unbound -y
          elif [ "$DISTRO" == "alpine" ]; then
            apk del unbound
          fi
          # Uninstall Pihole
          if [ -f "/etc/pihole/wireguard-manager" ]; then
            if pgrep systemd-journal; then
              systemctl disable pihole
              systemctl stop pihole
            else
              service pihole disable
              service pihole stop
            fi
            pihole uninstall
          fi
        fi
        # Delete wireguard Backup
        if [ -f "/var/backups/wireguard-manager.zip" ]; then
          read -rp "Do you really want to remove Wireguard Backup? (y/n): " -n 1 -r
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f /var/backups/wireguard-manager.zip
          elif [[ $REPLY =~ ^[Nn]$ ]]; then
            exit
          fi
        fi
        ;;
      9) # Update the script
        CURRENT_FILE_PATH="$(realpath "$0")"
        if [ -f "$CURRENT_FILE_PATH" ]; then
          curl -o "$CURRENT_FILE_PATH" $WIREGUARD_MANAGER_UPDATE
          chmod +x "$CURRENT_FILE_PATH" || exit
        fi
        ;;
      10) # Backup Wireguard Config
        if [ ! -d "/etc/wireguard" ]; then
          rm -f /var/backups/wireguard-manager.zip
          zip -r -j /var/backups/wireguard-manager.zip $WIREGUARD_CONFIG $WIREGUARD_MANAGER $WIREGUARD_PEER $WIREGUARD_INTERFACE
        else
          exit
        fi
        ;;
      11) # Restore Wireguard Config
        if [ -f "/var/backups/wireguard-manager.zip" ]; then
          rm -rf /etc/wireguard/
          unzip /var/backups/wireguard-manager.zip -d /etc/wireguard/
        else
          exit
        fi
        # Restart Wireguard
        if pgrep systemd-journal; then
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC restart
        fi
        ;;
      esac
    fi
  }

  # Running Questions Command
  wireguard-next-questions

  function wireguard-next-questions() {
    if [ -f "$WIREGUARD_PEER" ]; then
      echo "What do you want to do?"
      echo "   1) Show WireGuard Interface"
      echo "   2) Start WireGuard Interface"
      echo "   3) Stop WireGuard Interface"
      echo "   4) Restart WireGuard Interface"
      echo "   5) Reinstall WireGuard Interface"
      echo "   6) Uninstall WireGuard Interface"
      echo "   7) Update this script"
      echo "   8) Backup WireGuard Config"
      echo "   9) Restore WireGuard Config"
      until [[ "$WIREGUARD_OPTIONS" =~ ^[0-9]+$ ]] && [ "$WIREGUARD_OPTIONS" -ge 1 ] && [ "$WIREGUARD_OPTIONS" -le 9 ]; do
        read -rp "Select an Option [1-9]: " -e -i 1 WIREGUARD_OPTIONS
      done
      case $WIREGUARD_OPTIONS in
      1) # WG Show
        wg show
        ;;
      2) # Enable & Start Wireguard
        if pgrep systemd-journal; then
          systemctl enable wg-quick@$WIREGUARD_PUB_NIC
          systemctl start wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC enable
          service wg-quick@$WIREGUARD_PUB_NIC start
        fi
        ;;
      3) # Disable & Stop WireGuard
        if pgrep systemd-journal; then
          systemctl disable wg-quick@$WIREGUARD_PUB_NIC
          systemctl stop wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC disable
          service wg-quick@$WIREGUARD_PUB_NIC stop
        fi
        ;;
      4) # Restart WireGuard
        if pgrep systemd-journal; then
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC restart
        fi
        ;;
      5) # Reinstall Wireguard
        if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
          dpkg-reconfigure wireguard-dkms
          modprobe wireguard
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
          yum reinstall wireguard-dkms -y
          service wg-quick@$WIREGUARD_PUB_NIC restart
        elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
          pacman -Rs --noconfirm wireguard-tools
          service wg-quick@$WIREGUARD_PUB_NIC restart
        elif [ "$DISTRO" == "alpine" ]; then
          apk fix wireguard-tools
        fi
        ;;
      6) # Uninstall Wireguard and purging files
        if [ -f "$WIREGUARD_MANAGER" ]; then
          if pgrep systemd-journal; then
            systemctl disable wg-quick@$WIREGUARD_PUB_NIC
            wg-quick down $WIREGUARD_PUB_NIC
          else
            service wg-quick@$WIREGUARD_PUB_NIC disable
            wg-quick down $WIREGUARD_PUB_NIC
          fi
          # Removing Wireguard Files
          rm -rf /etc/wireguard
          rm -rf /etc/wireguard/clients
          rm -f /etc/wireguard/$WIREGUARD_PUB_NIC.conf
          rm -f /etc/sysctl.d/wireguard.conf
          if [ "$DISTRO" == "centos" ]; then
            yum remove wireguard qrencode haveged -y
          elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "kali" ]; }; then
            apt-get remove --purge wireguard qrencode -y
            rm -f /etc/apt/sources.list.d/unstable.list
            rm -f /etc/apt/preferences.d/limit-unstable
          elif [ "$DISTRO" == "pop" ]; then
            apt-get remove --purge wireguard qrencode haveged -y
          elif [ "$DISTRO" == "ubuntu" ]; then
            apt-get remove --purge wireguard qrencode haveged -y
            if pgrep systemd-journal; then
              systemctl enable systemd-resolved
              systemctl restart systemd-resolved
            else
              service systemd-resolved enable
              service systemd-resolved restart
            fi
          elif [ "$DISTRO" == "raspbian" ]; then
            apt-key del 04EE7237B7D453EC
            apt-get remove --purge wireguard qrencode haveged dirmngr -y
            rm -f /etc/apt/sources.list.d/unstable.list
            rm -f /etc/apt/preferences.d/limit-unstable
          elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
            pacman -Rs wireguard qrencode haveged -y
          elif [ "$DISTRO" == "fedora" ]; then
            dnf remove wireguard qrencode haveged -y
            rm -f /etc/yum.repos.d/wireguard.repo
          elif [ "$DISTRO" == "rhel" ]; then
            yum remove wireguard qrencode haveged -y
            rm -f /etc/yum.repos.d/wireguard.repo
          elif [ "$DISTRO" == "alpine" ]; then
            apk del wireguard-tools libqrencode haveged
          fi
        fi
        # Delete wireguard Backup
        if [ -f "/var/backups/wireguard-manager.zip" ]; then
          read -rp "Do you really want to remove Wireguard Backup? (y/n): " -n 1 -r
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f /var/backups/wireguard-manager.zip
          elif [[ $REPLY =~ ^[Nn]$ ]]; then
            exit
          fi
        fi
        ;;
      7) # Update the script
        CURRENT_FILE_PATH="$(realpath "$0")"
        if [ -f "$CURRENT_FILE_PATH" ]; then
          curl -o "$CURRENT_FILE_PATH" $WIREGUARD_MANAGER_UPDATE
          chmod +x "$CURRENT_FILE_PATH" || exit
        fi
        ;;
      8) # Backup Wireguard Config
        if [ ! -d "/etc/wireguard" ]; then
          rm -f /var/backups/wireguard-manager.zip
          zip -r -j /var/backups/wireguard-manager.zip $WIREGUARD_CONFIG $WIREGUARD_MANAGER $WIREGUARD_PEER $WIREGUARD_INTERFACE
        else
          exit
        fi
        ;;
      9) # Restore Wireguard Config
        if [ -f "/var/backups/wireguard-manager.zip" ]; then
          rm -rf /etc/wireguard/
          unzip /var/backups/wireguard-manager.zip -d /etc/wireguard/
        else
          exit
        fi
        # Restart Wireguard
        if pgrep systemd-journal; then
          systemctl restart wg-quick@$WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC restart
        fi
        ;;
      esac
    fi
  }

  # Running Questions Command
  wireguard-next-questions

fi
