{pkgs, ...}: {
  imports = [
    ./extensions.nix
    ./userSettings.nix
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.override {
      commandLineArgs = ''--password-store=gnome-libsecret'';
    };
  };
}
