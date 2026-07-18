{
  imports = [
    ../packages/desktop.nix
    ../modules/desktop
  ];

  home.sessionVariables = {
    BROWSER = "zen";
    TERMINAL = "kitty";
  };

  xdg.mimeApps.defaultApplications."inode/directory" = "thunar.desktop";
}
