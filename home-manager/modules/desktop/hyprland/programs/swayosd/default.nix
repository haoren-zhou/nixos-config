{
  services.swayosd = {
    enable = true;
    stylePath = ./style.css;
    topMargin = 0.85;
  };

  xdg.configFile."swayosd/config.toml".text = ''
    [server]
    show_percentage = true
  '';
}
