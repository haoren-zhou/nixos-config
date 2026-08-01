{
  inputs,
  user,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime

    ./mouse
  ];

  hardware.nvidia.open = true;

  hardware.i2c.enable = true;
  users.users.${user}.extraGroups = ["i2c"];

  boot.extraModulePackages = with config.boot.kernelPackages; [ddcci-driver];
  boot.kernelModules = ["ddcci-backlight"];

  # from: https://wiki.nixos.org/wiki/Backlight
  services.udev.extraRules = let
    bash = "${pkgs.bash}/bin/bash";
    ddcciDev = "NVIDIA i2c adapter 7 at 8:00.0";
    ddcciNode = "/sys/bus/i2c/devices/i2c-6/new_device";
  in ''
    SUBSYSTEM=="i2c", ACTION=="add", ATTR{name}=="${ddcciDev}", RUN+="${bash} -c 'sleep 30; printf ddcci\ 0x37 > ${ddcciNode}'"
  '';
}
