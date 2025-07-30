{pkgs, ...}: {
  home.packages = with pkgs; [
    ulauncher
  ];

  xdg.configFile = {
    "ulauncher/settings.json" = {
      source = ./settings.json;
    };
  };
}
