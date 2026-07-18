{
  user,
  homeStateVersion,
  ...
}: {
  imports = [
    ../packages/common.nix
    ../modules/common
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = homeStateVersion;
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs.home-manager.enable = true;
}
