{
  config,
  lib,
  ...
}: let
  palette = import ../../palette.nix {inherit lib;};
  inherit (palette) colors;
in {
  programs.swayimg = {
    enable = true;
    settings = {
      viewer.window = "${colors.background}ff";

      gallery = {
        window = "${colors.background}ff";
        background = "${colors.surface}ff";
        select = "${colors.surface-raised}ff";
        border_color = "${colors.accent}ff";
        border_width = 2;
        pstore = "yes";
      };

      list.all = "yes";

      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
        color = "${colors.text}ff";
      };

      "keys.viewer" = {
        h = "step_left 10";
        j = "step_down 10";
        k = "step_up 10";
        l = "step_right 10";
        "Shift+k" = "zoom keep";
      };

      "keys.gallery" = {
        h = "step_left";
        j = "step_down";
        k = "step_up";
        l = "step_right";
        g = "first_file";
        "Shift+g" = "last_file";
        "Ctrl+u" = "page_up";
        "Ctrl+d" = "page_down";
      };
    };
  };

  xdg.mimeApps.defaultApplicationPackages = [
    config.programs.swayimg.package
  ];
}
