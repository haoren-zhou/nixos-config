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

  # HACK: HP firmware quirk
  nixpkgs.overlays = [
    (final: prev: {
      efibootmgr = final.symlinkJoin {
        name = "efibootmgr-wrapped-${prev.efibootmgr.version}";
        paths = [
          (final.writeShellScriptBin "efibootmgr" ''
            valid_vars=$(${prev.efibootmgr}/bin/efibootmgr)
            new_args=()
            modify_next=0
            for arg in "$@"; do
              if [ "$modify_next" = "1" ]; then
                IFS=',' read -ra ORDER <<< "$arg"
                valid_order=()
                declare -A seen
                for entry in "''${ORDER[@]}"; do
                  if [[ "$valid_vars" == *"Boot$entry"* ]]; then
                    if [ -z "''${seen[$entry]:-}" ]; then
                      valid_order+=("$entry")
                      seen[$entry]=1
                    fi
                  fi
                done
                arg=$(IFS=,; echo "''${valid_order[*]}")
                modify_next=0
              fi
              if [ "$arg" = "-o" ]; then
                modify_next=1
              fi
              new_args+=("$arg")
            done
            exec ${prev.efibootmgr}/bin/efibootmgr "''${new_args[@]}"
          '')
          prev.efibootmgr
        ];
      };
    })
  ];

  services.openssh = {
    enable = true;
    ports = [39182];
    settings = {
      PasswordAuthentication = false;
      AllowUsers = null;
      PermitRootLogin = "prohibit-password";
    };
  };
  networking.firewall.allowedTCPPorts = [39182];

  # windows dual-boot
  boot.loader.limine.extraEntries = ''
    /Windows
      protocol: efi_chainload
      image_path: guid(c9db70df-ce04-40c5-861e-392ea2b1cb75):/EFI/Microsoft/Boot/bootmgfw.efi
  '';

  system.stateVersion = stateVersion;
}
