{
  pkgs,
  lib,
  ...
}: let
  palette = import ../../palette.nix {inherit lib;};
in {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = lib.getExe pkgs.kitty;
    font = "Inter 11";
    plugins = with pkgs; [
      rofi-emoji # https://github.com/Mange/rofi-emoji 🤯
      rofi-games # https://github.com/Rolv-Apneseth/rofi-games 🎮
    ];
    theme = "theme";
    extraConfig = {
      modi = "drun,run,filebrowser,window";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
      display-drun = "";
      display-run = "";
      display-window = "󱂬";
      display-filebrowser = "";
      display-emoji = "🤠";
      display-games = "";
      hover-select = true;
      me-select-entry = "MouseSecondary";
      me-accept-entry = "MousePrimary";
    };
  };

  xdg.dataFile."rofi/themes/theme.rasi".text =
    palette.rasiColors + builtins.readFile ./theme.rasi;
}
