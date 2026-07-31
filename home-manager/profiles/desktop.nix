{
  imports = [
    ../packages/desktop.nix
    ../modules/desktop
  ];

  home.sessionVariables = {
    BROWSER = "zen";
    TERMINAL = "kitty";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "thunar.desktop";

      "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "application/epub+zip" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "application/oxps" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "image/vnd.djvu" = "org.pwmt.zathura-djvu.desktop";
      "image/vnd.djvu+multipage" = "org.pwmt.zathura-djvu.desktop";
      "application/postscript" = "org.pwmt.zathura-ps.desktop";
    };
  };
}
