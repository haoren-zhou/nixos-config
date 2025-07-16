{ inputs, homeStateVersion, user, ... }:

{
  imports = [
    ./home-packages.nix

    ./modules/desktop/plasma-manager.nix
    ./modules/desktop/stylix.nix

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
