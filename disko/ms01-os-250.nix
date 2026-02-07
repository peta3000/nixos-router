# This module is used by the `disko` NixOS module (imported in the host’s
# `default.nix`) to create the *operating‑system* disk for the workstation.
# It creates a small EFI System Partition (ESP) of 512 MiB and a single
# ext4 partition that will be mounted as the system root (/).
#
# The device name is taken from the flake via `by-id` (see hosts/default.nix)
# so the layout is independent of whatever /dev/nvme* name the kernel gives
# the drive after a reboot.

{
  # -----------------------------------------------------------------
  # The `disko` module expects a top‑level attribute set with a
  # `devices` map.  We only need one physical disk, called `os`.
  # -----------------------------------------------------------------
  disko.devices = {
    # The physical disk – replace the placeholder with the real by‑id path
    # when you import the module (the host file will set the variable).
    disk.os = {
      device = "/dev/disk/by-id/nvme-INTENSO_SSD_1642507006001001"; # 250 GB SSD
      type   = "disk";

      # -----------------------------------------------------------------
      # Partition table: GPT (the default for modern UEFI systems)
      # -----------------------------------------------------------------
      content = {
        type = "gpt";

        partitions = {
          # -------------------------------------------------------------
          # Partition 1 – EFI System Partition (type EF00)
          # -------------------------------------------------------------
          esp = {
            size = "512M";                     # 512 MiB is plenty for ESP
            type = "EF00";                     # EFI System Partition
            label = "EFI";
            content = {
              type = "filesystem";
              format = "vfat";                  # FAT32 (required by UEFI)
              mountpoint = "/boot";             # NixOS expects boot here
            };
          };

          # -------------------------------------------------------------
          # Partition 2 – Linux root (type 8300)
          # -------------------------------------------------------------
          root = {
            size = "100%";                     # Fill the rest of the disk
            type = "8300";                     # Linux filesystem
            label = "disk-os-root";
            content = {
              type = "filesystem";
              format = "ext4";                  # Simple, rock‑solid
              mountpoint = "/";                 # This becomes the system /
            };
          };
        };
      };
    };
  };
}
