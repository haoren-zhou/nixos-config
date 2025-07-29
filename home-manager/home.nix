{ inputs, homeStateVersion, user, ... }:

{
  imports = [
    ./home-packages.nix

    ./modules/desktop/hyprland
    # ./modules.desktop/kde

    ./modules/programs
  ];


  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = homeStateVersion;
  };

  xdg.mimeApps.defaultApplications."inode/directory" = "thunar.desktop";

  home.file = {
  };

  programs.home-manager.enable = true;
}
