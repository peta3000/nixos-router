# Single source of truth for VLANs/subnets and interface roles.
{
  # WAN selection:
  # - testing: enp1s0 (RJ45)
  # - production: enp5s0d1 (SFP+)
  wan = {
    testing = "enp1s0";
    production = "enp5s0d1";
  };

  lan = {
    bridge = "br-switch";
    # Initial bridge/trunk ports (LAN side)
    ports = [ "enp2s0" "enp3s0" "enp5s0" ];
  };

  # VLANs: VLAN 1 untagged (PVID) on all bridge ports.
  # VLAN 20/30/40/50 tagged on all bridge ports (for now).
  vlans = {
    lan     = { id = 1;  ifname = "br-switch";    cidr = "192.168.5.1/24";   };
    guest   = { id = 20; ifname = "br-switch.20"; cidr = "192.168.20.1/24";  };
    iot     = { id = 30; ifname = "br-switch.30"; cidr = "192.168.30.1/24";  };
    printer = { id = 40; ifname = "br-switch.40"; cidr = "192.168.40.1/24";  };
    dmz     = { id = 50; ifname = "br-switch.50"; cidr = "192.168.50.1/24";  };
  };

  dhcp = {
    lan     = { start = 100; end = 249; lease = "12h"; };
    guest   = { start = 100; end = 249; lease = "12h"; };
    iot     = { start = 100; end = 249; lease = "12h"; };
    printer = { start = 100; end = 249; lease = "12h"; };
    dmz     = { start = 100; end = 249; lease = "12h"; };
  };
}
