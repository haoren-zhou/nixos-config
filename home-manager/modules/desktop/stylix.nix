{pkgs, inputs, ...}:

{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;

    targets = {
      vscode.enable = false;
    };

    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/helios.yaml";

    fonts = {
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-color-emoji;
      };
      monospace = {
        name = "JetBrains Mono";
        package = pkgs.jetbrains-mono;
      };
      sansSerif = {
        name = "Noto Sans";
        package = pkgs.noto-fonts;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };

      sizes = {
        terminal = 13;
        applications = 11;
      };
    };

    iconTheme = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };

    image = ../../../wallpapers/wallpaper.png;
  };
}
