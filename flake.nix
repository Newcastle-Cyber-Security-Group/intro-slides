{
  description = "NCSG Introduction Slides";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    nixpkgs.url = "github:nixOS/nixpkgs/nixpkgs-unstable";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        flake-compat.follows = "flake-compat";
      };
    };
  };

  outputs = { self, flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays.git-cliff = _final: prev: {
          git-cliff = prev.rustPlatform.buildRustPackage rec {
            inherit (prev.git-cliff) doCheck meta pname;

            version = "2.0.2";

            buildInputs = prev.git-cliff.buildInputs
              ++ (prev.lib.optionals prev.stdenv.isDarwin
                (with prev.darwin.apple_sdk.frameworks; [
                  CoreServices
                  SystemConfiguration
                ]));

            src = prev.fetchFromGitHub {
              owner = "orhun";
              repo = "git-cliff";
              rev = "v${version}";
              hash = "sha256-m8xnsj6z/QBeya3CQBkQ+/eGSCZVKpTa8y1zt+3NeIo=";
            };

            cargoHash = "sha256-axh62ogKI2UnlI4aXLDB3fIg1CowQN8xRKWmZi5Kgig=";
          };
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlays.git-cliff ];
        };
      in {
        apps = {
          build = {
            type = "app";
            program = builtins.toString (pkgs.writers.writeBash "build" ''
              ${pkgs.hugo}/bin/hugo -s .
            '');
          };

          develop = {
            type = "app";
            program = builtins.toString (pkgs.writers.writeBash "develop" ''
              ${pkgs.hugo}/bin/hugo server
            '');
          };
        };

        checks.pre-commit = self.inputs.pre-commit-hooks.lib.${system}.run {
          src = self;
          hooks = {
            # Builtin hooks
            actionlint.enable = true;
            conform.enable = true;
            deadnix.enable = true;
            nixfmt.enable = true;
            prettier.enable = true;
            statix.enable = true;
            typos.enable = true;

            # Custom hooks
            git-cliff = {
              enable = true;
              name = "Git Cliff";
              entry = "${pkgs.git-cliff}/bin/git-cliff --output CHANGELOG.md";
              language = "system";
              pass_filenames = false;
            };

            statix-write = {
              enable = true;
              name = "Statix Write";
              entry = "${pkgs.statix}/bin/statix fix";
              language = "system";
              pass_filenames = false;
            };
          };

          # Settings for builtin hooks, see also: https://github.com/cachix/pre-commit-hooks.nix/blob/master/modules/hooks.nix
          settings = {
            deadnix.edit = true;
            nixfmt.width = 80;
            prettier.write = true;
            typos.locale = "en-au";
          };
        };

        devShells = let
          name = "hugo-revealjs";
          nodePackages = with pkgs.nodePackages; [ eslint prettier ];
          packages =
            (with pkgs; [ deadnix go hugo nixfmt statix typos trivy vulnix ])
            ++ nodePackages;
        in {
          default = self.devShells.${system}.${name};
          "${name}" = pkgs.mkShell {
            inherit name packages;
            inherit (self.checks.${system}.pre-commit) shellHook;
          };
        };
      });
}
