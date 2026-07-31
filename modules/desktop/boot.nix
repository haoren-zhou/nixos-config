{
  pkgs,
  pkgs-unstable,
  ...
}: {
  # Bootloader.
  boot.loader = {
    systemd-boot.enable = false;
    grub.enable = false;

    timeout = null;

    limine = {
      enable = true;
      maxGenerations = 8;
      style = {
        wallpapers = [../../wallpapers/basement.png];
        wallpaperStyle = "stretched";
      };
      secureBoot = {
        enable = true;
        autoGenerateKeys = true;
        autoEnrollKeys = {
          enable = true;
        };
      };
    };
    efi.canTouchEfiVariables = true;
  };
  environment.systemPackages = with pkgs; [
    sbctl
  ];
}
