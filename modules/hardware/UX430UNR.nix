{ lib, config, pkgs, ... }: let
  nvidiaDriverChannel = config.boot.kernelPackages.nvidiaPackages.stable; # stable, latest, beta, etc.
in {
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true;
    packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
    };
  };
  # nixpkgs.config.allowUnfree = true;

  # nixpkgs.config.packageOverrides = pkgs: {
  #   vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  # };

  # boot.blacklistedKernelModules = [ "nouveau" ];

  boot.kernelParams = [
    "intel_pstate=active"
    "i915.enable_guc=2" # Enable GuC/HuC firmware loading
    "i915.enable_psr=1" # Panel Self Refresh for power savings
    "i915.enable_fbc=1" # Framebuffer compression
    "i915.fastboot=1" # Skip unnecessary mode sets at boot
    "mem_sleep_default=deep" # Allow deepest sleep states
    "i915.enable_dc=2" # Display power saving
    "nvme.noacpi=1" # Helps with NVME power consumption

    "nvidia-drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];

  # Load the driver
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    nvidia = {
      open = false;
      # nvidiaPersistenced = true;
      nvidiaSettings = false;
      powerManagement.enable = true; # This can cause sleep/suspend to fail.
      modesetting.enable = true;
      package = nvidiaDriverChannel;
      
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;

        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    graphics = {
      enable = true;
      package = nvidiaDriverChannel;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl

        nvidia-vaapi-driver

        libva-utils
        mesa-demos
      ];
    };
  };

  # nixpkgs.config = {
  #   nvidia.acceptLicense = true;
  #   cudaSupport = true;
  #   # allowUnfreePredicate = pkg:
  #   #   builtins.elem (lib.getName pkg) [
  #   #     "cudatoolkit"
  #   #     "nvidia-persistenced"
  #   #     "nvidia-settings"
  #   #     "nvidia-x11"
  #   #   ];
  # };

  # Thermal and Noise Management
  services.thermald.enable = true;
  services.throttled.enable = true;
}
