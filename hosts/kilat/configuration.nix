{
  stateVersion,
  hardware,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/${hardware}.nix
    ../../modules/common
    ../../modules/desktop
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = stateVersion;

  # windows dual-boot
  boot.loader.limine.extraEntries = ''
    /Windows
      protocol: efi_chainload
      image_path: guid(80fbf49e-dd1f-419d-9c42-5ef8f46daf5f):/EFI/Microsoft/Boot/bootmgfw.efi
  '';
}
