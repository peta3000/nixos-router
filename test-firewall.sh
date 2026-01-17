#!/usr/bin/env bash
set -e

# NixOS Router Firewall Testing Script
echo "=== NixOS Router Firewall Testing ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Current Firewall Rules ===${NC}"
echo "Displaying current nftables ruleset:"
nft list ruleset

echo ""
echo -e "${BLUE}=== Interface Status ===${NC}"
ip link show | grep -E "(br-switch|enp[0-9])"

echo ""
echo -e "${BLUE}=== VLAN Interface Status ===${NC}"
ip addr show | grep -E "(br-switch|192\.168\.[0-9]+\.1)" || echo "No VLAN interfaces found"

echo ""
echo -e "${BLUE}=== Routing Table ===${NC}"
ip route show

echo ""
echo -e "${BLUE}=== Basic Connectivity Tests ===${NC}"
echo "Testing router accessibility:"

# Test local connectivity
if ping -c 1 -W 1 127.0.0.1 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Loopback interface working${NC}"
else
    echo -e "${RED}✗ Loopback interface failed${NC}"
fi

# Test bridge interface
if ip link show br-switch >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Bridge interface exists${NC}"
else
    echo -e "${RED}✗ Bridge interface not found${NC}"
fi

echo ""
echo -e "${BLUE}=== Network Services ===${NC}"
echo "Checking DNS service:"
if systemctl is-active --quiet systemd-resolved; then
    echo -e "${GREEN}✓ systemd-resolved is running${NC}"
else
    echo -e "${YELLOW}⚠ systemd-resolved not running${NC}"
fi

echo ""
echo -e "${BLUE}=== DHCP Services ===${NC}"
if systemctl is-active --quiet systemd-networkd; then
    echo -e "${GREEN}✓ systemd-networkd is running${NC}"
else
    echo -e "${RED}✗ systemd-networkd not running${NC}"
fi

echo ""
echo -e "${BLUE}=== Manual Test Commands ===${NC}"
echo "To test from different VLANs, you'll need devices in each network."
echo "Here are some useful test commands:"
echo ""
echo "# Test DNS resolution:"
echo "nslookup google.com 192.168.5.1"
echo ""
echo "# Test connectivity between VLANs:"
echo "ping 192.168.20.1  # From any VLAN to Guest gateway"
echo "ping 192.168.30.1  # From any VLAN to IoT gateway"
echo ""
echo "# Test HTTP/HTTPS to DMZ (from WAN):"
echo "curl -I http://192.168.50.100"
echo "curl -I https://192.168.50.100"
echo ""
echo "# Test blocked connections:"
echo "# From Guest VLAN, try: telnet 192.168.5.1 22 (should be blocked)"
echo "# From IoT VLAN, try: telnet 192.168.5.100 22 (should be blocked)"

echo ""
echo -e "${GREEN}Firewall test complete!${NC}"
echo "Review the output above for any issues."