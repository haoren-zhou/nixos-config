{
  pkgs,
  ...
}: {
  # these will be overlayed in nixpkgs automatically.
  sddm-astronaut = pkgs.callPackage ./sddm-themes/astronaut.nix {theme = "purple_leaves";};
}
