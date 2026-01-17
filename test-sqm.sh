#!/usr/bin/env bash

# SQM/CAKE Testing Script for NixOS Router
echo "=== SQM/CAKE Performance Testing ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WAN_IFACE="enp1s0"  # Adjust based on your config

echo -e "${BLUE}=== SQM Service Status ===${NC}"
systemctl status sqm-setup --no-pager || echo "SQM service not found"

echo ""
echo -e "${BLUE}=== Current Traffic Control Configuration ===${NC}"
echo "Root qdisc on $WAN_IFACE:"
tc -s qdisc show dev "$WAN_IFACE"

echo ""
echo "IFB interface (if exists):"
tc -s qdisc show dev "ifb4$WAN_IFACE" 2>/dev/null || echo "No IFB interface found"

echo ""
echo -e "${BLUE}=== CAKE Statistics ===${NC}"
tc -s -d qdisc show dev "$WAN_IFACE" | grep -A 30 "qdisc cake" || echo "CAKE not configured"

echo ""
echo -e "${BLUE}=== Interface Statistics ===${NC}"
ip -s link show "$WAN_IFACE"

echo ""
echo -e "${BLUE}=== Network Buffer Configuration ===${NC}"
echo "Current sysctl network settings:"
sysctl net.core.default_qdisc
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.rmem_max
sysctl net.core.wmem_max
sysctl net.core.netdev_max_backlog

echo ""
echo -e "${BLUE}=== Bufferbloat Testing Commands ===${NC}"
echo "To test for bufferbloat, run these commands from a client:"
echo ""
echo -e "${YELLOW}1. Basic speed test while monitoring latency:${NC}"
echo "# In one terminal:"
echo "ping -i 0.2 8.8.8.8"
echo "# In another terminal:"
echo "curl -o /dev/null http://speedtest.your-isp.com/large-file.zip"
echo ""
echo -e "${YELLOW}2. Waveform bufferbloat test:${NC}"
echo "curl -s https://www.waveform.com/tools/bufferbloat | bash"
echo ""
echo -e "${YELLOW}3. DSLReports speed test:${NC}"
echo "# Go to: http://www.dslreports.com/speedtest"
echo "# Look for A+ grade on bufferbloat"
echo ""
echo -e "${YELLOW}4. Flent testing (if installed):${NC}"
echo "flent rrul -p all_scaled -l 60 -H 8.8.8.8 -t 'RRUL test'"

echo ""
echo -e "${BLUE}=== Expected Results with SQM/CAKE ===${NC}"
echo "✓ Ping latency should remain low (<50ms increase) during speed tests"
echo "✓ CAKE should show active tins and flow management"
echo "✓ Bufferbloat grade should be A or A+"
echo "✓ Upload/download should be smooth and fair"

echo ""
echo -e "${BLUE}=== Manual SQM Commands ===${NC}"
echo "Start SQM: systemctl start sqm-setup"
echo "Stop SQM: systemctl stop sqm-setup"  
echo "Restart SQM: systemctl restart sqm-setup"
echo "View detailed stats: /etc/sqm-status.sh"

echo ""
echo -e "${GREEN}SQM test information displayed!${NC}"
echo "Run the suggested tests to validate SQM performance."