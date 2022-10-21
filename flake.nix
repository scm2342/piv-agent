{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    alejandra.url = "github:kamadorueda/alejandra/3.0.0";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    flake-compat,
    alejandra,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        formatter = alejandra.defaultPackage.${system};
        nixosModules.piv-agent = {
          lib,
          config,
          ...
        }:
          with lib; let
            cfg = config.services.piv-agent;
          in {
            options.services.piv-agent = {
              enable = mkEnableOption "Enables the piv-agent service";
            };
            config = mkIf cfg.enable {
              systemd.user.services.piv-agent = {
                description = "piv-agent service";
                serviceConfig.ExecStart = "${self.packages.${system}.piv-agent}/bin/piv-agent serve --agent-types=ssh=0;gpg=1";
              };
              systemd.user.sockets.piv-agent = {
                description = "piv-agent socket activation";
                listenStreams = [
                  "%t/piv-agent/ssh.socket"
                  "%t/gnupg/S.gpg-agent"
                ];
                wantedBy = ["sockets.target"];
              };
              environment.extraInit = ''
                if [ -z "$SSH_AUTH_SOCK" -a -n "$XDG_RUNTIME_DIR" ]; then
                  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/piv-agent/ssh.socket"
                fi
              '';
            };
          };
        packages = flake-utils.lib.flattenTree {
          piv-agent = pkgs.buildGoModule rec {
            name = "piv-agent";
            version = self.shortRev or "dirty";
            src = builtins.path {
              path = ./.;
              name = "piv-agent";
            };
            vendorSha256 = "sha256-Vch+8Hxx6yoBMMWBIxcCmSUPE/LOG/IHlUhcTA9BmwI=";
            nativeBuildInputs = [pkgs.pkg-config pkgs.makeWrapper];
            buildInputs = [pkgs.pcsclite pkgs.pinentry-gtk2];
            postFixup = ''
              wrapProgram $out/bin/piv-agent \
                --suffix-each PATH : ${pkgs.lib.makeBinPath [
                pkgs.pinentry-gtk2
              ]}
            '';
            meta = {
              description = "piv-agent";
              homepage = "https://github.com/smlx/piv-agent";
            };
          };
        };
        defaultPackage = packages.piv-agent;
        apps.piv-agent = flake-utils.lib.mkApp {drv = packages.piv-agent;};
        defaultApp = apps.piv-agent;

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.go_1_19
            pkgs.mockgen
            (pkgs.buildGoModule rec {
              name = "enumer";
              version = "1.5.7";
              src = pkgs.fetchFromGitHub {
                owner = "dmarkham";
                repo = name;
                rev = "v${version}";
                sha256 = "sha256-2fVWrrWOiCtg7I3Lul2PgQ2u/qDEDioPSB61Tp0rfEo=";
              };
              vendorSha256 = "sha256-BmFv0ytRnjaB7z7Gb+38Fw2ObagnaFMnMhlejhaGxsk=";
              meta = {
                description = "enumer";
                homepage = "https://github.com/dmarkham/enumer";
              };
            })
          ];
        };
      }
    );
}
