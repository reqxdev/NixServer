{
  description = "NixServer - headless NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, disko, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      disks = (import ./disko.nix).disko.devices.disk;

      # Replace USERNAME with your login name before installing.
      username = "Paul";
    in
    {
      # nix run github:reqxdev/NixServer#install
      packages.${system}.install = pkgs.writeShellApplication {
        name = "install-nixserver";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          iputils
          gnused
          nixos-install-tools
          util-linux
          disko.packages.${system}.disko
        ];
        text = ''
          export NIXSERVER_FLAKE=${pkgs.lib.escapeShellArg "${self}#NixServer"}
          export NIXSERVER_USER=${pkgs.lib.escapeShellArg username}
          export NIXSERVER_SOURCE=${pkgs.lib.escapeShellArg "${self}"}
        '' + builtins.readFile ./install.sh;
      };

      # Used by the installer: boot SSD always, storage HDD only when given.
      diskoConfigurations.install =
        { device, data ? null, ... }:
        {
          disko.devices.disk = {
            main = disks.main // { inherit device; };
          } // nixpkgs.lib.optionalAttrs (data != null) {
            data = disks.data // { device = data; };
          };
        };

      nixosConfigurations.NixServer = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit username; };
        modules = [
          ./configuration.nix
          ./disko.nix
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
        ];
      };
    };
}
