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

  home.file = {
  };

  programs.home-manager.enable = true;
}
