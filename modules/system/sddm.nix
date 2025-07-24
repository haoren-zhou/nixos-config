{ pkgs, ... }:

{
  # Enable sddm login manager
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      enableHidpi = true;
      package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      settings.Theme.CursorTheme = "Bibata-Modern-Ice";
      extraPackages = with pkgs; [
        kdePackages.qtmultimedia
        kdePackages.qtsvg
        kdePackages.qtvirtualkeyboard
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    sddm-astronaut # Overlayed
  ];

}
