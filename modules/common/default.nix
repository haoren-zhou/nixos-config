{
  imports = [
    ./docker.nix
    ./home-manager.nix
    ./kernel.nix
    ./networking.nix
    ./nh.nix
    ./nix.nix
    ./nix-ld.nix
    ./tailscale.nix
    ./timezone_locale.nix
    ./user.nix
  ];

  programs.npm.enable = true;
}
