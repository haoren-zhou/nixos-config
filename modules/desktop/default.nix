{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./boot.nix
    ./disk.nix
    ./env.nix
    ./hyprland.nix
    # ./kde.nix
    ./sddm.nix
    ./thunar.nix
  ];

  services.printing.enable = true;
}
