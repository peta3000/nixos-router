# disko configuration for R86S router - NVMe SSD testing
# Usage: Replace NVME_DISK_ID with actual disk ID during installation
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/NVME_DISK_ID";
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
          
          # Swap partition - 4GB for router appliance
          swap = {
            size = "4G";
            content = {
              type = "swap";
              randomEncryption = true; # Secure swap
            };
          };
          
          # Root partition - rest of disk
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
  
  # Additional filesystem optimizations for router appliance
  fileSystems."/" = {
    options = [ "noatime" "commit=60" ]; # Optimize for SSD and reduce writes
  };
  
  fileSystems."/boot" = {
    options = [ "umask=0077" ]; # Secure boot partition
  };
}