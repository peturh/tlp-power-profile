{
  description = "TLP-backed power-profile widget for Dank Material Shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAllSystems (pkgs: rec {
        tlp-power-profile-helper = pkgs.stdenvNoCC.mkDerivation {
          pname = "tlp-power-profile-helper";
          version = "0.1.0";
          src = ./helper;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -Dm755 tlp-power-profile-helper \
              $out/bin/tlp-power-profile-helper
            wrapProgram $out/bin/tlp-power-profile-helper \
              --prefix PATH : ${pkgs.tlp}/bin
            runHook postInstall
          '';
          meta = {
            description = "Companion helper for the tlp-power-profile DMS plugin";
            mainProgram = "tlp-power-profile-helper";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
          };
        };

        tlp-power-profile-plugin = pkgs.stdenvNoCC.mkDerivation {
          pname = "tlp-power-profile-plugin";
          version = "0.1.0";
          src = ./.;
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -d $out/share/DankMaterialShell/plugins/tlp-power-profile
            cp plugin.json qmldir *.qml \
              $out/share/DankMaterialShell/plugins/tlp-power-profile/
            runHook postInstall
          '';
          meta = {
            description = "QML assets for the tlp-power-profile DMS plugin";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
          };
        };

        default = tlp-power-profile-helper;
      });

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.tlpPowerProfile;
          helper = self.packages.${pkgs.stdenv.hostPlatform.system}.tlp-power-profile-helper;
        in {
          options.services.tlpPowerProfile = {
            enable = lib.mkEnableOption
              "the tlp-power-profile DMS plugin helper + polkit rule";

            powerGroup = lib.mkOption {
              type = lib.types.str;
              default = "power";
              description = ''
                Group whose members can invoke `tlp` and the helper via
                `pkexec` without a password prompt. Created if it doesn't
                already exist. Add yourself with
                `users.users.<you>.extraGroups = [ "power" ];`
                (or `sudo gpasswd -a "$USER" power` imperatively).
              '';
            };

            enableTlp = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Also enable NixOS's `services.tlp`.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ helper pkgs.tlp ];
            users.groups.${cfg.powerGroup} = { };
            services.tlp.enable = lib.mkDefault cfg.enableTlp;

            security.polkit.extraConfig = ''
              polkit.addRule(function(action, subject) {
                  if (action.id !== "org.freedesktop.policykit.exec") return;
                  var path = action.lookup("program");
                  if ((path === "${pkgs.tlp}/bin/tlp" ||
                       path === "${helper}/bin/tlp-power-profile-helper") &&
                      subject.isInGroup("${cfg.powerGroup}")) {
                      return polkit.Result.YES;
                  }
              });
            '';
          };
        };
    };
}
