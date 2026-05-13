{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
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
  };

  outputs = {
    self,
    nixpkgs,
    nixos-wsl,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    system = "x86_64-linux";
    homeStateVersion = "25.05";
    user = "nixos";
    hosts = [
      {
        hostname = "nixos";
        stateVersion = "25.05";
      }
    ];

    makeSystem = {
      hostname,
      stateVersion,
      hardwareConfig,
    }:
      nixpkgs.lib.nixosSystem {
        system = system;
        specialArgs = {
          inherit inputs outputs stateVersion hostname hardwareConfig user;
          pkgs-unstable = import inputs.nixpkgs-unstable {
            system = system;
            config = {
              allowUnfree = true;
            };
          };
        };

        modules = [
	  nixos-wsl.nixosModules.default
          ./hosts/${hostname}/configuration.nix
        ];
      };
  in {
    nixosConfigurations = nixpkgs.lib.foldl' (configs: host:
      configs
      // {
        "${host.hostname}" = makeSystem {
          inherit (host) hostname stateVersion hardwareConfig;
        };
      }) {}
    hosts;

    homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        inherit inputs homeStateVersion user;
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = system;
          config = {
            allowUnfree = true;
          };
        };
      };

      modules = [
        ./home-manager/home.nix
      ];
    };
  };
}
