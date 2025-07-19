{ pkgs, ... }:
{
  programs.plasma = {
    enable = true;

    workspace = {
      cursor = {
        theme = "Bibata-Modern-Ice";
        size = 24;
      };
    };

    hotkeys.commands."launch-kitty" = {
      name = "Launch Kitty";
      key = "Ctrl+Alt+T";
      command = "kitty";
    };
  };
}