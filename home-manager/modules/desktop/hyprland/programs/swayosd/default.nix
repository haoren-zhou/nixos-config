{
  pkgs,
  lib,
  ...
}: let
  palette = import ../../palette.nix {inherit lib;};
in {
  services.swayosd = {
    enable = true;
    stylePath = pkgs.writeText "swayosd-style.css" (palette.defineColors + builtins.readFile ./style.css);
    topMargin = 0.85;
  };

  xdg.configFile."swayosd/config.toml".text = ''
    [server]
    show_percentage = true
  '';
}
