{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    crane.url = "github:ipetkov/crane";
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem = {
        pkgs,
        self',
        ...
      }: {
        formatter = pkgs.alejandra;

        packages = let
          inherit (pkgs) lib;

          craneLib = inputs.crane.mkLib pkgs;
          src = craneLib.cleanCargoSource ./.;

          commonArgs = {
            inherit src;
            strictDeps = true;
          };

          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          crateArgs =
            commonArgs
            // {
              inherit cargoArtifacts;
              inherit (craneLib.crateNameFromCargoToml {inherit src;}) version;
              doCheck = false;
            };

          fileSetForCrate = crate:
            lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./Cargo.toml
                ./Cargo.lock
                crate
              ];
            };
        in rec {
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self'.packages;
        };
      };
    };
}
