# This module expects that the Btrfs pool is labeled "DATA512"
# (see disko/ms01-data-512.nix).  The pool is mounted at /persist,
# and we then bind‑mount the relevant sub‑volumes into the normal
# filesystem hierarchy.
#
# You can extend the list of bind‑mounts later (e.g. add a Docker
# volume, a Media directory, etc.) – just add another entry to the
# `fileSystems` attrset.

{ config, lib, pkgs, ... }:

{
  # -----------------------------------------------------------------
  # 1️⃣  Mount the Btrfs pool at /persist
  # -----------------------------------------------------------------
  fileSystems."/persist" = {
    device = "/dev/disk/by-id/nvme-Fanxiang_S500Pro_512GB_FXS500Pro251040783-part1";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" ];
  };

  # -----------------------------------------------------------------
  # 2️⃣  Bind‑mount the mutable sub‑volumes.
  #    The left‑hand side is the *path the system expects*,
  #    the right‑hand side is the *real location* on the Btrfs pool.
  # -----------------------------------------------------------------
  fileSystems."/home" = {
    device = "/persist/home";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib" = {
    device = "/persist/var-lib";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/log" = {
    device = "/persist/var-log";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/etc/ssh" = {
    device = "/persist/etc-ssh";
    fsType = "none";
    options = [ "bind" ];
  };

  # Optional – LLM model files (you can change the mount‑point if you prefer)
  fileSystems."/srv/llm" = {
    device = "/persist/llm";
    fsType = "none";
    options = [ "bind" ];
  };
}
