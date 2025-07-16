{ inputs, homeStateVersion, user, ... }:

{
  imports = [
    ./home-packages.nix
    ./modules/programs/btop.nix
    ./modules/programs/micro.nix
    ./modules/programs/git.nix
    ./modules/programs/gh.nix
    ./modules/desktop/plasma-manager.nix
    ./modules/desktop/stylix.nix
    ./modules/programs/zen.nix
    ./modules/programs/bat.nix
    ./modules/programs/zsh.nix
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
