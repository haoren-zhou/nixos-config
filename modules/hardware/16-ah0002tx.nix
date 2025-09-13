{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    # inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
  ];

  boot.kernelModules = ["hp-wmi"];
  boot.kernelParams = ["acpi_backlight=nvidia_wmi_ec"];

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia.open = true;

  hardware.nvidia = {
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
    };
    modesetting.enable = true;
  };

  # Thermal and Noise Management
  services.thermald.enable = true;
}
