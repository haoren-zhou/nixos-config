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
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxcb
      libxkbfile
      zlib
      fuse
      alsa-lib
    ];
  };
}
