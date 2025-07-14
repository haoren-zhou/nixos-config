{ homeStateVersion, user, ... }:

{
  imports = [
    ./home-packages.nix
    # ../../modules/home-manager/btop.nix
    # ../../modules/home-manager/micro.nix
    # ../../modules/home-manager/git.nix
    # ../../modules/home-manager/gh.nix
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
