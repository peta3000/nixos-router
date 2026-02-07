# This module creates a single Btrfs partition that will be mounted at
# `/archive` (or any mount point you prefer).  The label `DATA1TB` makes
# it easy to refer to from NixOS configuration.  You can keep the
# existing three‑partition layout (EFI, swap, /nix/store) and simply
# re‑use the *big* partition (currently `nvme1n1p3`) as a Btrfs pool,
# or you can wipe the whole disk and start from scratch.
#
# The example below *wipes* the disk and builds a brand‑new Btrfs pool.
# Uncomment the `wipe` line only after you have verified that the OS
# migration succeeded and you no longer need any data on this drive.

{
  disko.devices = {
    disk.data1tb = {
      device = "/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_24382D801781"; # 1 TB SSD
      type   = "disk";

      # -----------------------------------------------------------------
      # If you want to keep the current partition layout (EFI+SWAP+store)
      # comment the next line out and *do not* run `sgdisk` here.
      # -----------------------------------------------------------------
      # wipe = true;   # destroys existing partitions – use only after backup!

      content = {
        type = "gpt";

        partitions = {
          # -------------------------------------------------------------
          # One big Btrfs partition that occupies the whole disk.
          # -------------------------------------------------------------
          data = {
            size = "100%";
            type = "8300";
            content = {
              type = "filesystem";
              format = "btrfs";
              fsLabel  = "DATA1TB"; # with correct btrfs syntax
              mountpoint = "/archive";   # you can change the mountpoint later
              mountOptions = [ "compress=zstd" "noatime" ];
            };
          };
        };
      };
    };
  };
}
