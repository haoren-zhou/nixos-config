{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/7ced9122cff2163c6a0212b8d1ec8c33a1660806";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    stylix = {
      url = "github:danth/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:maximoffua/zen-browser.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    self.submodules = true;

    nvchad-starter = {
      url = ./nvim;
      flake = false;
    };

    nix4nvchad = {
      url = "github:nix-community/nix4nvchad";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nvchad-starter.follows = "nvchad-starter";
    };

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-vscode-extensions,
    nixos-wsl,
    ...
  } @ inputs: let
    inherit (self) outputs;
    system = "x86_64-linux";
    homeStateVersion = "25.05";
    user = "hr";

    hosts = [
      {
        hostname = "zenbook";
        profile = "desktop";
        stateVersion = "25.05";
        hardware = "UX430UNR";
      }
      {
        hostname = "omen";
        profile = "desktop";
        stateVersion = "25.05";
        hardware = "16-ah0002tx";
      }
      {
        hostname = "wsl";
        profile = "wsl";
        stateVersion = "25.05";
        hardware = null;
      }
    ];

    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    makeSystem = host:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs outputs pkgs-unstable user;
          inherit (host) hostname stateVersion hardware profile;
        };
        modules =
          [./hosts/${host.hostname}/configuration.nix]
          ++ nixpkgs.lib.optional (host.profile == "desktop") inputs.stylix.nixosModules.stylix
          ++ nixpkgs.lib.optional (host.profile == "wsl") nixos-wsl.nixosModules.default;
      };

    makeHome = host:
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit inputs pkgs-unstable user homeStateVersion;
          inherit (host) profile;
        };
        modules =
          [
            ./home-manager/profiles/common.nix
            {nixpkgs.overlays = [nix-vscode-extensions.overlays.default];}
          ]
          ++ nixpkgs.lib.optionals (host.profile == "desktop") [
            ./home-manager/profiles/desktop.nix
            inputs.plasma-manager.homeModules.plasma-manager
            inputs.spicetify-nix.homeManagerModules.spicetify
          ];
      };

    byHost = f:
      builtins.listToAttrs (map (h: {
          name = h.hostname;
          value = f h;
        })
        hosts);
  in {
    nixosConfigurations = byHost makeSystem;
    homeConfigurations = builtins.listToAttrs (map (h: {
        name = "${user}@${h.hostname}";
        value = makeHome h;
      })
      hosts);
  };
}
