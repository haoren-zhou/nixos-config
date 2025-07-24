{ inputs, homeStateVersion, user, ... }:

{
  imports = [
    ./home-packages.nix

    # ./modules/desktop/plasma-manager.nix
    ./modules/desktop/stylix.nix
    # ./modules/desktop/qt.nix
    # ./modules/desktop/ulauncher

    ./modules/desktop/hyprland

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
