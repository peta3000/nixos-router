# This module encapsulates everything needed to turn the Mini‑Forum
# into a fully‑featured GPU workstation.  It is imported by the host
# configuration (hosts/ms-01-workstation/default.nix).
#
# Feel free to adjust the desktop manager (`gnome`, `plasma5`, or
# `sway`) to your taste.  The example below uses GNOME + GDM, which
# works “out of the box” for most users.

{ config, lib, pkgs, ... }:

{
  # -----------------------------------------------------------------
  # 0️⃣  Import the GNOME remote‑desktop module
  # -----------------------------------------------------------------
  imports = [
    # Adjust the path if you use a custom overlay; <nixpkgs> resolves to the
    # nixpkgs version that the flake pulls in.
    <nixpkgs>/nixos/modules/services/gnome/remote-desktop.nix
  ];

  # -----------------------------------------------------------------
  # 1️⃣  Enable the OpenGL stack and the GPU drivers
  # -----------------------------------------------------------------
  hardware.opengl.enable = true;                     # generic OpenGL support

  # Explicitly list the video drivers we need:
  services.xserver.videoDrivers = [ "intel" "nvidia" ];

  # NVIDIA proprietary driver (choose the appropriate version for your card)
  # The version is taken from the defaults in nixpkgs; you can pin a specific
  # version by overriding `hardware.nvidia.package`.
  hardware.nvidia.modesetting.enable = true;         # required for PRIME off‑load
  hardware.nvidia.open = false;                     # we use the proprietary driver
  hardware.nvidia.powerManagement.enable = true;    # optional, saves power when idle

  # -----------------------------------------------------------------
  # 2️⃣  Xorg / Wayland configuration
  # -----------------------------------------------------------------
  services.xserver.enable = true;                   # start Xorg
  services.xserver.displayManager.gdm.enable = true;   # GDM (GNOME Display Manager)
  services.xserver.desktopManager.gnome.enable = true; # GNOME desktop

  # If you prefer KDE Plasma, replace the two lines above with:
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # ---- Optional Wayland‑only setup (uncomment to replace Xorg) ----
  # services.xserver.enable = false;
  # programs.sway.enable = true;      # lightweight Wayland compositor
  # services.wayvnc.enable = true;   # VNC over Wayland (if you want headless VNC)

  # -----------------------------------------------------------------
  # 3️⃣  Enable PRIME (iGPU primary, RTX off‑load)
  # -----------------------------------------------------------------
  # The `nvidia-drm` module needs a kernel parameter `modeset=1`.
  # The `nvidia` module in NixOS does this automatically when
  # `hardware.nvidia.modesetting.enable = true;` is set.
  # For completeness you can also add the option in /etc/modprobe.d:
  boot.kernelModules = [ "nvidia" "i915" ];  # make sure both drivers are loaded

  # -----------------------------------------------------------------
  # 4️⃣  Steam & Vulkan (gaming stack)
  # -----------------------------------------------------------------
  programs.steam.enable = true;                     # pulls in Steam client, runtime
  hardware.opengl.driSupport32Bit = true;           # 32‑bit Vulkan for older games
  hardware.opengl.extraPackages = with pkgs; [
    vulkan-tools            # `vulkaninfo`, `vkcube`
    vulkan-headers
    libva
    libvdpau
  ];

  # -----------------------------------------------------------------
  # 5️⃣ Remote‑desktop (VNC) – GNOME Remote Desktop (works on X & Wayland)
  # -----------------------------------------------------------------
  services.gnome.remoteDesktop.enable = true;
  services.gnome.remoteDesktop.vnc.enable = true;
  services.gnome.remoteDesktop.vnc.passwordFile = "/persist/vncpasswd";
  services.gnome.remoteDesktop.vnc.geometry = "1920x1080";
  # optional: enable RDP as well
  # services.gnome.remoteDesktop.rdp.enable = true;

  # -----------------------------------------------------------------
  # 6️⃣  System packages you probably want on a workstation
  # -----------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Editors / utilities
    vim git htop wget curl

    # Media / graphics
    gimp krita inkscape ffmpeg
    blender kdenlive

    # Audio / video
    mpv vlc

    # Development / debugging (optional)
    python3Full python3Packages.pip
    clang gcc
    neovim
  ];

  # -----------------------------------------------------------------
  # 7️⃣  Allow the user (peter) to access the GPU devices
  # -----------------------------------------------------------------
  users.users.peter = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "docker" ];   # add any groups you need
  };

  # -----------------------------------------------------------------
  # 8️⃣  Optional: expose the LLM inference service (same as on the router)
  # -----------------------------------------------------------------
  # If you already have a systemd service definition for the LLM API
  # (e.g. in modules/router/llm-service.nix), you can simply import it
  # here, or copy the block verbatim.  For brevity we only hint at it:
  #
  # imports = [ ../../modules/router/llm-service.nix ];
}
