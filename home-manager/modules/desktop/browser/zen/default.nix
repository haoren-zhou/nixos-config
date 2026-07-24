{
  pkgs,
  inputs,
  ...
}: {
  home.packages = [inputs.zen-browser.packages.${pkgs.stdenv.system}.default];
}
