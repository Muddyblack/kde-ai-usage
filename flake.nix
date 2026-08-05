{
  description = "AI usage widget for KDE Plasma 6 and Hyprland/Quickshell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f system);
      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "ai-usage-widget";
            version = metadata.KPlugin.Version;
            src = ./package;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              
              # Install plasmoid package
              root=$out/share/plasma/plasmoids/org.muddyblack.aiUsageWidget
              mkdir -p "$root"
              cp -r . "$root/"

              # Register icon in hicolor theme so Plasma Widget Explorer picks it up
              mkdir -p "$out/share/icons/hicolor/scalable/apps"
              cp contents/icons/org.muddyblack.aiUsageWidget.svg "$out/share/icons/hicolor/scalable/apps/org.muddyblack.aiUsageWidget.svg"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Multi-provider AI usage widget for KDE Plasma 6";
              license = licenses.mit;
              platforms = platforms.linux;
              homepage = "https://github.com/Muddyblack/kde-ai-usage";
            };
          };

          tray-helper = pkgs.stdenv.mkDerivation {
            pname = "ai-usage-tray";
            version = metadata.KPlugin.Version;
            src = ./hyprland/tray;
            nativeBuildInputs = with pkgs; [ cmake ninja qt6.wrapQtAppsHook ];
            buildInputs = with pkgs; [ qt6.qtbase ];
          };
        });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          quickshellDesktop = pkgs.makeDesktopItem {
            name = "org.quickshell";
            desktopName = "Quickshell";
            comment = "QtQuick desktop shell runtime";
            # xdg-desktop-portal resolves this entry in the portal daemon's
            # environment, where a flake-only Quickshell is not on PATH.
            exec = "${pkgs.quickshell}/bin/qs";
            icon = "org.muddyblack.aiUsageWidget";
            terminal = false;
            noDisplay = true;
            categories = [ "Utility" ];
          };
        in {
          view = {
            type = "app";
            program = toString (pkgs.writeShellScript "view" ''
              if [ ! -f "$PWD/package/metadata.json" ]; then
                echo "error: no plasmoid at $PWD/package" >&2
                echo "  'nix run .#view' previews your working copy, so run it from the repo root." >&2
                exit 1
              fi
              exec nix shell nixpkgs#kdePackages.plasma-sdk nixpkgs#kdePackages.plasma-desktop -c plasmoidviewer \
                -a "$PWD/package" -f "''${1:-planar}"
            '');
          };
          pack = {
            type = "app";
            program = toString (pkgs.writeShellScript "pack" ''
              set -euo pipefail
              here="$PWD"
              ver="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$here/package/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
              name="$(basename "$here")"
              out="$here/$name-$ver.plasmoid"
              rm -f "$out"
              (cd "$here/package" && ${pkgs.zip}/bin/zip -r "$out" . -x '*.swp' '*~')
              echo "wrote $out"
            '');
          };
          hyprland = {
            type = "app";
            program = toString (pkgs.writeShellScript "ai-usage-hyprland" ''
              set -eu
              export PATH=${pkgs.lib.makeBinPath [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.findutils
                pkgs.gawk
                pkgs.gnugrep
                pkgs.gnused
                pkgs.jq
                pkgs.perl
              ]}:"$PATH"
              config=${self}/hyprland/shell.qml
              desktop_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/applications"
              ${pkgs.coreutils}/bin/mkdir -p "$desktop_dir"
              ${pkgs.coreutils}/bin/install -m 0644 \
                ${quickshellDesktop}/share/applications/org.quickshell.desktop \
                "$desktop_dir/org.quickshell.desktop"
              ${self.packages.${system}.tray-helper}/bin/ai-usage-tray \
                ${pkgs.quickshell}/bin/qs "$config" \
                ${self}/package/contents/tools/sh/get-ai-usage &
              tray_pid=$!
              trap 'kill "$tray_pid" 2>/dev/null || true' EXIT INT TERM
              ${pkgs.quickshell}/bin/qs -p "$config"
            '');
          };
        });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            name = "ai-usage-widget-dev";
            packages = with pkgs; [
              qt6.qtdeclarative
              kdePackages.kpackage
              kdePackages.plasma-sdk
              pre-commit
              zip
            ];
            shellHook = ''
              pre-commit install -f --install-hooks
              echo "ai-usage-widget dev shell ready"
              echo "  make help        — list targets (view, install, pack, tag)"
            '';
          };
        });
    };
}
