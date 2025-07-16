{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    nixos-hardware.url = "github:NixOS/nixos-hardware/7ced9122cff2163c6a0212b8d1ec8c33a1660806";

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

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = { self, nixpkgs, home-manager, nix-vscode-extensions, ... }@inputs: let
    system = "x86_64-linux";
    homeStateVersion = "25.05";
    user = "hr";
    hosts = [
      { hostname = "nixos"; stateVersion = "25.05"; hardwareConfig = "UX430UNR";}
    ];

    makeSystem = { hostname, stateVersion, hardwareConfig }: nixpkgs.lib.nixosSystem {
      system = system;
      specialArgs = {
        inherit inputs stateVersion hostname hardwareConfig user;
      };

      modules = [
        inputs.stylix.nixosModules.stylix
        ./hosts/${hostname}/configuration.nix
      ];
    };

  in {
     nixosConfigurations = nixpkgs.lib.foldl' (configs: host:
      configs // {
        "${host.hostname}" = makeSystem {
          inherit (host) hostname stateVersion hardwareConfig;
        };
      }) {} hosts;

    homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        inherit inputs homeStateVersion user;
      };

      modules = [
        inputs.plasma-manager.homeManagerModules.plasma-manager
        ./home-manager/home.nix
        {
          nixpkgs.overlays = [
            nix-vscode-extensions.overlays.default
          ];
        }
      ];
    };
  };
}
