{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane.url = "github:ipetkov/crane";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
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
      }: let
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
              ./crates/core
              crate
            ];
          };
      in {
        formatter = pkgs.alejandra;

        packages = rec {
          sondert-server = craneLib.buildPackage (crateArgs
            // {
              pname = "sondert-server";
              cargoExtraArgs = "-p sondert-server";
              src = fileSetForCrate ./crates/server;
            });
          sondert-cli = craneLib.buildPackage (crateArgs
            // {
              pname = "sondert-cli";
              cargoExtraArgs = "-p sondert-cli";
              src = fileSetForCrate ./crates/cli;
            });

          default = sondert-server;
        };

        checks =
          self'.packages
          // {
            workspace-clippy = craneLib.cargoClippy (commonArgs
              // {
                inherit cargoArtifacts;
                cargoClippyExtraArgs = "--all-targets -- --deny warnings";
              });

            workspace-fmt = craneLib.cargoFmt {
              inherit src;
            };

            workspace-toml-fmt = craneLib.taploFmt {
              src = lib.sources.sourceFilesBySuffices src [".toml"];
            };

            workspace-audit = craneLib.cargoAudit {
              inherit src;
              inherit (inputs) advisory-db;
            };

            workspace-deny = craneLib.cargoDeny {
              inherit src;
            };

            workspace-nextest = craneLib.cargoNextest (commonArgs
              // {
                inherit cargoArtifacts;
                partitions = 1;
                partitionType = "count";
              });
          };

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self'.checks;
        };
      };
    };
}
