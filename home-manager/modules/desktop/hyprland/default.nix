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
  ];

  home.packages = with pkgs; [
    hyprpaper
    hyprpicker
    cliphist
    grimblast
    swappy
    libnotify
    brightnessctl
    networkmanagerapplet
    pamixer
    pavucontrol
    playerctl
    waybar
    wtype
    wl-clipboard
    xdotool
    yad
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
    theme = {
      name = lib.mkForce "adw-gtk3-dark";
      package = lib.mkForce pkgs.adw-gtk3;
    };
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
    extraConfig = ''
      local scripts = "${./scripts}"
      local hyprsunset = "${lib.getExe pkgs.hyprsunset}"

      ${builtins.readFile ./config.lua}
    '';
  };
}
