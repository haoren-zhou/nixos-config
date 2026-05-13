{pkgs, ...}: {
  imports = [
    ./docker.nix
    ./nh.nix
    ./nix-ld.nix
    ./tailscale.nix
  ];

  # List services that you want to enable:
  programs.npm.enable = true;
}
