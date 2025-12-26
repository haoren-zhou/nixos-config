# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  outputs,
  stateVersion,
  hostname,
  hardwareConfig,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ../../modules/system
    ../../modules/programs
  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
      # allowUnfreePredicate = _: true;
    };
  };

  wsl = {
    enable = true;
    defaultUser = "nixos";
  };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  system.stateVersion = stateVersion;
}
