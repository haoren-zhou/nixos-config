{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../common.nix
    ./binds.nix
    ./hyprpaper.nix

    ./programs/waybar
    ./programs/wlogout
    ./programs/rofi
    ./programs/hypridle
    ./programs/hyprlock
    ./programs/swaync
    ./programs/swayosd
    ./programs/swayimg
  ];

  home.packages = with pkgs; [
    hyprpaper
    hyprpicker
    hyprsunset
    cliphist
    grimblast
    wf-recorder
    swappy
    libnotify
    brightnessctl
    networkmanagerapplet
    pamixer
    pavucontrol
    playerctl
    wl-clipboard
  ];

  xdg.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [xdg-desktop-portal-hyprland xdg-desktop-portal-gtk];
    xdgOpenUsePortal = true;
  };

  dconf.enable = true;
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  gtk = {
    enable = true;
    gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  xdg.configFile."hypr/icons" = {
    source = ./icons;
    recursive = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    systemd = {
      enable = true;
      variables = ["--all"];
    };
    extraConfig = let
      inherit (import ./palette.nix {inherit lib;}) colors;
      rgba = hex: alpha: "rgba(${lib.removePrefix "#" hex}${alpha})";
    in ''
      local scripts = "${./scripts}"
      local hyprsunset = "${lib.getExe pkgs.hyprsunset}"
      local swayosd = "${lib.getExe' pkgs.swayosd "swayosd-client"}"

      local border_active = {
        colors = { "${rgba colors.border-active "ff"}", "${rgba colors.border-active-alt "ff"}" },
        angle = 45,
      }
      local border_inactive = { colors = { "${rgba colors.border "ff"}" } }

      ${builtins.readFile ./config.lua}
    '';
  };
}
