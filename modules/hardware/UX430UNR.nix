{ inputs, pkgs, lib, ... }:

{
  imports = 
    [
      inputs.nixos-hardware.nixosModules.common-pc-laptop
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      inputs.nixos-hardware.nixosModules.asus-battery

      inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only

      inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    ];
  hardware.asus.battery =
    {
      chargeUpto = 80;   # Maximum level of charge for your battery, as a percentage.
      enableChargeUptoScript = true; # Whether to add charge-upto to environment.systemPackages. `charge-upto 100` temporarily sets the charge limit to 100%, useful if you're going to need the extra battery on a longer journey.
    };

  services.xserver.videoDrivers = [ "nvidia" ];
  
  # The open source driver does not support Pascal GPUs.
  hardware.nvidia.open = false;

  hardware.nvidia = {
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    dynamicBoost.enable = lib.mkForce false; # Dynamic boost is not supported on Pascal architeture
  };

  # Thermal and Noise Management
  services.thermald.enable = true;
  services.throttled.enable = true;

  powerManagement.cpuFreqGovernor = "powersave";
}