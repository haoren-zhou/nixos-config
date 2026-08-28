{pkgs, ...}: {
  # Input settings
  services.libinput.enable = true;

  services.dbus.packages = [pkgs.swayosd];
  systemd.packages = [pkgs.swayosd];
  systemd.services.swayosd-libinput-backend.wantedBy = ["graphical.target"];

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    xkb.variant = "";
    excludePackages = with pkgs; [xterm];
  };

  # Setup keyring
  services.gnome.gnome-keyring.enable = true;

  security = {
    polkit.enable = true;
    #sudo.wheelNeedsPassword = false;
    pam.services = {
      sddm.enableGnomeKeyring = true;
      login.enableGnomeKeyring = true;
      sddm-helper.enableGnomeKeyring = true;
      hyprlock.enableGnomeKeyring = true;
    };
  };

  programs.seahorse.enable = true;

  systemd.user.services.hyprpolkitagent = {
    description = "Hyprpolkitagent - Polkit authentication agent";
    wantedBy = ["graphical-session.target"];
    wants = ["graphical-session.target"];
    after = ["graphical-session.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  services.displayManager.defaultSession = "hyprland";

  programs.hyprland = {
    enable = true;
    # withUWSM = true;
  };

  fonts.packages = [
    pkgs.inter
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.noto-fonts-cjk-sans
  ];

  environment.systemPackages = with pkgs; [
    killall
    lm_sensors
    jq
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.qtvirtualkeyboard

    # devenv
    # devbox
    # shellify
  ];
}
