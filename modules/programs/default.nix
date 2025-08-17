{pkgs, ...}: {
  imports = [
    ./docker.nix
    ./nh.nix
    ./nix-ld.nix
    ./thunar.nix
  ];

  # List services that you want to enable:
  programs.npm.enable = true;
}
