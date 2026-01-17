# disko configuration for R86S router - Internal eMMC (production)
# Usage: Replace EMMC_DISK_ID with actual disk ID during installation
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/EMMC_DISK_ID";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # EFI boot partition
          boot = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "defaults" "umask=0077" ];
            };
          };
          
          # Swap partition - 2GB (smaller for eMMC)
          swap = {
            size = "2G";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
          
          # Root partition - rest of disk (~114GB)
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "defaults" "noatime" "commit=120" ]; # Gentler on eMMC
            };
          };
        };
      };
    };
  };
  
  # eMMC-specific optimizations
  fileSystems."/" = {
    options = [ "noatime" "commit=120" "barrier=0" ]; # Reduce eMMC wear
  };
  
  fileSystems."/boot" = {
    options = [ "umask=0077" ];
  };
}