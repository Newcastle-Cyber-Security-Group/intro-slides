{
  description = "NCSG Introduction Slides";

  inputs = {
    devshell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/devshell";
    };

    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixOS/nixpkgs/nixpkgs-unstable";

    git-hooks = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/pre-commit-hooks.nix";
    };
  };

  outputs =
    {
      devshell,
      flake-utils,
      nixpkgs,
      self,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          overlays = [ devshell.overlays.default ];
          inherit system;
        };
      in
      {
        apps = {
          build = {
            type = "app";
            program = builtins.toString (
              pkgs.writers.writeBash "build" ''
                ${pkgs.hugo}/bin/hugo -s .
              ''
            );
          };

          develop = {
            type = "app";
            program = builtins.toString (
              pkgs.writers.writeBash "develop" ''
                ${pkgs.hugo}/bin/hugo server
              ''
            );
          };
        };

        checks.pre-commit = self.inputs.git-hooks.lib.${system}.run {
          src = self;
          hooks = {
            # Builtin hooks
            actionlint.enable = true;
            conform.enable = true;
            deadnix = {
              enable = true;
              settings.edit = true;
            };

            nixfmt = {
              enable = true;
              package = pkgs.nixfmt-rfc-style;
              settings.width = 80;
            };

            prettier = {
              enable = true;
              settings = {
                ignore-path = [ self.packages.${system}.prettierignore ];
                write = true;
              };
            };

            statix.enable = true;

            typos = {
              enable = true;
              settings = {
                exclude = "LICENSE";
                ignored-words = [
                  "organized"
                ];
                locale = "en-au";
              };
            };

            # Custom hooks
            git-cliff = {
              enable = false;
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
        };

        devShells.default = pkgs.devshell.mkShell {
          devshell.startup.git-hooks.text = self.checks.${system}.pre-commit.shellHook;
          name = "hugo-revealjs";
          packages = with pkgs; [
            deadnix
            go
            hugo
            nixfmt-rfc-style
            nodePackages.prettier
            statix
            typos
            vulnix
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;

        packages.prettierignore = pkgs.writeTextFile {
          name = ".prettierignore";
          text = pkgs.lib.concatStringsSep "\n" [
            ".pre-commit-config.yaml"
            ".prettierignore"
            "*.nix"
            "CHANGELOG.md"
            "result"
          ];
        };
      }
    );
}
