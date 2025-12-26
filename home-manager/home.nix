{
  inputs,
  homeStateVersion,
  user,
  ...
}: {
  imports = [
    ./home-packages.nix
    ./modules/programs
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = homeStateVersion;
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "zen";
      TERMINAL = "kitty";
    };
  };

  xdg.mimeApps.defaultApplications."inode/directory" = "thunar.desktop";

  home.file = {
  };

  programs.home-manager.enable = true;
}
