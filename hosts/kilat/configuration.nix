{
  stateVersion,
  hardware,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/${hardware}.nix
    ../../modules/common
    ../../modules/desktop
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = stateVersion;
}
