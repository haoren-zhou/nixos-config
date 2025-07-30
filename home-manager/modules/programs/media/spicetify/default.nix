{
  pkgs,
  inputs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in {
  programs.spicetify = {
    enable = true;
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      copyLyrics
      hidePodcasts
      shuffle
    ];
    enabledCustomApps = with spicePkgs.apps; [];
    # theme = spicePkgs.themes.bloom;
  };
}
