{
  user,
  stateVersion,
  ...
}: {
  imports = [
    ../../modules/common
  ];

  wsl = {
    enable = true;
    defaultUser = user;
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = stateVersion;
}
