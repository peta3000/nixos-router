# This module creates a **single Btrfs partition** that will be mounted at
# `/persist`.  We keep the layout simple (one partition covering the whole
# disk) because we will later create sub‑volumes for /home, /var/lib, etc.
# The Btrfs filesystem is created with the label `DATA512` so we can
# reference it in `configuration.nix` or other modules by label.

{
  disko.devices = {
    disk.data512 = {
      device = "/dev/disk/by-id/nvme-Fanxiang_S500Pro_512GB_FXS500Pro251040783"; # 512 GB SSD
      type   = "disk";

      content = {
        type = "gpt";

        partitions = {
          # -------------------------------------------------------------
          # One partition that takes the whole disk – type 8300 (Linux fs)
          # -------------------------------------------------------------
          data = {
            size = "100%";
            type = "8300";
            label = "DATA512";
            content = {
              type = "filesystem";
              format = "btrfs";                # Btrfs for compression + snapshots
              mountpoint = "/persist";         # will be mounted at /persist
              mountOptions = [ "compress=zstd" "noatime" ];
            };
          };
        };
      };
    };
  };
}
