{pkgs, ...}: {
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      dbus
      glib
      gtk3
      libGL
      libxkbcommon
      mesa
      openssl
      pango
      pipewire
      systemd
      vulkan-loader
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libxkbfile
      zlib
      fuse
      alsa-lib
    ];
  };
}
