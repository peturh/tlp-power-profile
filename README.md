# tlp-power-profile

A [Dank Material Shell][dms] plugin that replaces the built-in battery / power-profile widget with one backed by **TLP** instead of `power-profiles-daemon`.

The widget shows battery state and exposes TLP's power modes (`tlp ac` / `tlp bat`) and charge thresholds (`tlp setcharge`) — features `power-profiles-daemon` does not provide.

- Distro-agnostic — runs anywhere DMS + TLP do (Arch, Fedora, NixOS, Debian, …).
- Compositor-agnostic — runs anywhere DMS does (hyprland, niri, …).
- Three default power profiles, fully editable in DMS settings (rename, reicon, add, remove).
- Configurable privilege escalation: `pkexec` (default), `sudo -n`, or `none`.
- Battery charge thresholds with start/stop sliders + Apply button.

## Install

> NixOS users: skip this section and jump to [NixOS](#nixos) below — the flake handles steps 2 and 3 declaratively.

### 1. Symlink the plugin into DMS

```sh
git clone https://github.com/<you>/tlp-power-profile.git
ln -s "$PWD/tlp-power-profile" ~/.config/DankMaterialShell/plugins/tlp-power-profile
```

In DMS: **Settings → Plugins → Scan for Plugins** → enable **TLP Power Profile** → add to the DankBar widget list.

### 2. Install the helper script (optional)

The default *Performance* profile invokes a helper that layers cpufreq-governor / EPP / turbo / platform_profile overrides on top of `tlp ac`. If you don't need that overlay, you can change the *Performance* profile's command to plain `tlp ac` in settings and skip this step.

```sh
sudo install -m 0755 helper/tlp-power-profile-helper /usr/local/bin/tlp-power-profile-helper
```

### 3. Grant password-less access to `tlp`

TLP requires root for every state change. To avoid a password prompt on every click, set up **one** of the two routes below — `pkexec` is what the plugin uses by default.

#### Route A: polkit + pkexec (recommended)

Create `/etc/polkit-1/rules.d/49-tlp-power-profile.rules`:

```js
polkit.addRule(function(action, subject) {
    if (action.id !== "org.freedesktop.policykit.exec") return;
    var path = action.lookup("program");
    if ((path === "/usr/bin/tlp" || path === "/usr/sbin/tlp" ||
         path === "/usr/local/bin/tlp-power-profile-helper") &&
        subject.isInGroup("power")) {
        return polkit.Result.YES;
    }
});
```

Then add your user to the `power` group:

```sh
sudo groupadd -f power
sudo gpasswd -a "$USER" power
# log out + back in so the new group membership takes effect
```

Adjust the binary paths to match your distro (`which tlp`).

#### Route B: sudoers

Create `/etc/sudoers.d/tlp-power-profile` (always edit via `visudo -f` to catch syntax errors):

```
%wheel ALL=(root) NOPASSWD: /usr/bin/tlp, /usr/local/bin/tlp-power-profile-helper
```

Replace `%wheel` with your distro's sudoers group (`%sudo` on Debian/Ubuntu) and adjust binary paths.

Then in **DMS Settings → Plugins → TLP Power Profile**, switch *Privilege mode* to `sudo -n`.

#### Route C: none

If you're running the DMS session as root, or you've granted file capabilities to `tlp` some other way, set *Privilege mode* to *None (raw)* and the plugin will invoke commands without any prefix.

## NixOS

The repo ships a flake that exposes:

- `packages.<system>.tlp-power-profile-helper` — the helper script, wrapped so `tlp` is on `PATH` even under `pkexec`.
- `packages.<system>.tlp-power-profile-plugin` — the QML assets, installed under `share/DankMaterialShell/plugins/tlp-power-profile`.
- `nixosModules.default` — installs the helper, creates the `power` group, and drops the polkit rule so members of that group can invoke `tlp` and the helper without a password.

### Flake setup

Add this repo as an input and import the module:

```nix
{
  inputs.tlp-power-profile.url = "github:<you>/tlp-power-profile";

  outputs = { self, nixpkgs, tlp-power-profile, ... }: {
    nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        tlp-power-profile.nixosModules.default
        ({ ... }: {
          services.tlpPowerProfile.enable = true;
          # Optional — defaults shown:
          # services.tlpPowerProfile.powerGroup = "power";
          # services.tlpPowerProfile.enableTlp  = true;   # turns on services.tlp

          # Add your user to the group that's allowed pkexec-without-password
          users.users.<you>.extraGroups = [ "power" ];
        })
      ];
    };
  };
}
```

Rebuild (`sudo nixos-rebuild switch --flake .#<host>`) and the helper appears at `/run/current-system/sw/bin/tlp-power-profile-helper`, with `tlp` and the helper both reachable via `pkexec` without a password prompt.

### Plugin QML files

DMS reads plugins from `~/.config/DankMaterialShell/plugins/`, which is per-user state — NixOS doesn't manage that path directly. Pick one of:

```sh
# Option A — clone + symlink (matches the dev workflow, easy to hack on)
git clone https://github.com/<you>/tlp-power-profile.git ~/src/tlp-power-profile
ln -s ~/src/tlp-power-profile ~/.config/DankMaterialShell/plugins/tlp-power-profile

# Option B — symlink the flake's plugin output (reproducible, read-only)
nix build github:<you>/tlp-power-profile#tlp-power-profile-plugin -o ~/.tlp-power-profile-result
ln -s ~/.tlp-power-profile-result/share/DankMaterialShell/plugins/tlp-power-profile \
      ~/.config/DankMaterialShell/plugins/tlp-power-profile
```

With home-manager, the equivalent of Option B is:

```nix
xdg.configFile."DankMaterialShell/plugins/tlp-power-profile".source =
  "${tlp-power-profile.packages.${pkgs.system}.tlp-power-profile-plugin}/share/DankMaterialShell/plugins/tlp-power-profile";
```

Then in DMS: **Settings → Plugins → Scan for Plugins** → enable **TLP Power Profile** → add to the DankBar.

## Configuration

All settings live in **DMS Settings → Plugins → TLP Power Profile**:

- **Poll interval** — how often `tlp-stat` is read (default 5000ms).
- **Privilege mode** — `pkexec`, `sudo -n`, or none.
- **Power profiles** — full list editor: icon, label, command. Add/remove freely. The active profile's icon shows in the bar pill; the popout exposes one button per profile.
- **Battery name** — empty = use TLP's config defaults. Auto-detected name shown as placeholder.
- **Charge thresholds** — start/stop sliders + Apply button. Hidden on machines without a battery. Constraint: `stop > start + 3`.

## Default profiles

| Profile     | Command                                  |
|-------------|------------------------------------------|
| Power Save  | `tlp bat`                                |
| Balanced    | `tlp ac`                                 |
| Performance | `tlp-power-profile-helper performance`   |

If you skip the helper script install, change *Performance* to `tlp ac` (or any command of your choice).

## Troubleshooting

- **Plugin doesn't show up after symlink**: `dms ipc call plugins list` to confirm DMS sees it; `dms ipc call plugins status tlpPowerProfile` for load errors.
- **"TLP call failed — check privilege setup" toast**: privilege escalation is rejected. Run the profile's command manually in a terminal (`pkexec tlp ac`) to see the real error.
- **Profile button click does nothing**: open a terminal, watch `journalctl -f --user`, click the button — QML errors surface there.
- **Charge thresholds slider snaps back**: TLP may be re-applying configured defaults at the next AC plug event. To make changes permanent, set `START_CHARGE_THRESH_BAT*` / `STOP_CHARGE_THRESH_BAT*` in `/etc/tlp.conf`.

## Development

There is no build / lint / test toolchain — QML is loaded at runtime by DMS.

```sh
# After file edits, hot-reload without restarting DMS:
dms ipc call plugins reload tlpPowerProfile

# If you change plugin.json or add/remove files:
dms restart
```

[dms]: https://github.com/AvengeMedia/DankMaterialShell
