# disko configuration for R86S router - eMMC production with complete wipe
# Usage: Replace EMMC_DISK_ID with actual disk ID during installation
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/EMMC_DISK_ID";
      type = "disk";
      # Force complete wipe and repartition
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
          
          # Root partition - rest of disk (no swap partition)
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "defaults" "noatime" ];
            };
          };
        };
      };
    };
  };
  
  # Force complete disk wipe before partitioning
  disko.enableDiskWipe = true;
  
  # Filesystem optimizations for router appliance
  fileSystems."/" = {
    options = [ "noatime" "commit=60" ];
  };
  
  fileSystems."/boot" = {
    options = [ "umask=0077" ];
  };
}