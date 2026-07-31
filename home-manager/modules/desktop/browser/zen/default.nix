{
  pkgs,
  inputs,
  ...
}: let
  package = inputs.zen-browser.packages.${pkgs.stdenv.system}.default;
in {
  home.packages = [package];

  xdg.mimeApps.defaultApplicationPackages = [package];
}
