# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, stateVersion, hostname, hardwareConfig, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/hardware/${hardwareConfig}.nix
      ../../modules/system
    ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    docker-compose
    pkgs.home-manager
  ];

  # programs.nix-ld.enable = true;

  # List services that you want to enable:
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  system.stateVersion = stateVersion;

}
