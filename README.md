# nixos

Personal NixOS + home-manager flake, unified across desktop and WSL.

Hosts:

| host | profile | machine |
|---|---|---|
| `zenbook` | desktop | Asus UX430 (hyprland) |
| `omen` | desktop | HP Omen 16-ah0002tx (hyprland) |
| `wsl` | wsl | WSL2 on Windows (cli only) |

## Structure

```
flake.nix                                # inputs, hosts list, per-profile wiring
hosts/<host>/configuration.nix           # thin host entrypoint
  hardware-configuration.nix             # nixos-generate-config output (physical hosts)
modules/
  common/         shared NixOS modules (kernel, nix, networking, user, docker, nh, ...)
  desktop/        gui-only NixOS modules (audio, hyprland, sddm, thunar, ...)
  hardware/       per-model modules (UX430UNR, 16-ah0002tx, ...)
home-manager/
  packages/{common,desktop}.nix          # home.packages by category
  profiles/{common,desktop}.nix          # entrypoints (composed by flake)
  modules/
    common/       shared program modules (bat, git, zsh, nvchad, vscode, ...)
    desktop/      gui-only program modules (zen, kitty, spicetify, thunar, ...)
nvim/                                    # nvchad config (git submodule)
```

Profile controls what a host gets:

- `desktop` → `modules/common` + `modules/desktop`, stylix, plasma-manager, spicetify HM modules
- `wsl` → `modules/common` + `nixos-wsl` module

Home-manager always gets `profiles/common.nix`. Desktop profile additionally gets `profiles/desktop.nix` plus the gui-only flake modules.

## Install: physical host

Assumes NixOS is installed and booted. **Easiest path: create the `hr` user during `nixos-install`** — matches the flake, no mid-rebuild user swap. If the installer left you with a different username, either recreate the installer step with `hr`, or apply this flake with `sudo nixos-rebuild boot --flake .#<hostname>` and reboot into `hr` before continuing.

```sh
# 1. Clone with submodules (nvchad-starter is one).
git clone --recurse-submodules https://github.com/haoren-zhou/nixos-config.git ~/nixos
cd ~/nixos

# 2. Generate hardware config for this machine.
sudo nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
mkdir -p hosts/<hostname>   # if <hostname> is new

# 3. New hardware model? Add a module under modules/hardware/.
#    Copy modules/hardware/UX430UNR.nix as a template; adjust nixos-hardware imports.

# 4. Register the host in flake.nix by appending to the `hosts` list:
#      { hostname = "<hostname>"; profile = "desktop"; stateVersion = "25.05"; hardware = "<model>"; }

# 5. Create hosts/<hostname>/configuration.nix (copy hosts/zenbook/configuration.nix).

# 6. First rebuild — must be explicit since current hostname doesn't match yet.
sudo nixos-rebuild switch --flake .#<hostname>

# 7. Set the hr password, then log in as hr.
sudo passwd hr
# logout, log back in as hr, or: su - hr

# 8. Move the flake into hr's home (nh expects it at ~/nixos).
sudo mv /home/<oldUser>/nixos /home/hr/nixos && sudo chown -R hr:users /home/hr/nixos
cd ~/nixos

# 9. First home-manager switch.
home-manager switch --flake .#hr@<hostname>

# 10. Reboot to pick up the new hostname / kernel cleanly.
sudo reboot
```

From here, `nh os switch` and `nh home switch` auto-detect the host.

## Install: WSL

From Windows PowerShell:

```powershell
wsl --install NixOS
# Or: download nixos-wsl.wsl from https://github.com/nix-community/NixOS-WSL/releases
#     wsl --import NixOS C:\wsl\NixOS <path-to-.wsl>
```

Inside the fresh WSL shell (user is `nixos`):

```sh
# Set a password for the default user so sudo works.
passwd

# Update channels once — required before nixos-rebuild works on a fresh install.
sudo nix-channel --update

git clone --recurse-submodules https://github.com/haoren-zhou/nixos-config.git ~/nixos
cd ~/nixos

# Use `boot`, NOT `switch`, when the rebuild changes wsl.defaultUser
# (nixos-wsl docs: `switch` can leave the new user account misconfigured).
sudo nixos-rebuild boot --flake .#wsl
```

Back in PowerShell — the terminate + root-shell dance is what actually flips the default user:

```powershell
wsl --terminate NixOS
wsl -d NixOS --user root   # opens a root shell in the new generation
```

Inside that root shell, set the hr password, then exit:

```sh
passwd hr
exit
```

Back in PowerShell:

```powershell
wsl --terminate NixOS
```

Reopen WSL — you're now `hr@wsl`. Finish setup:

```sh
sudo mv /home/nixos/nixos /home/hr/nixos && sudo chown -R hr:users /home/hr/nixos
cd ~/nixos
home-manager switch --flake .#hr@wsl

# Once confirmed working, drop /home/nixos.
sudo rm -rf /home/nixos
```

## Daily usage

```sh
nh os switch          # rebuild system (auto-detects host)
nh home switch        # rebuild home (auto-detects hr@$hostname)

nix flake update                      # bump every input
nix flake update nixpkgs-unstable     # bump one
```

### Add a package

- Shared cli/dev tool → `home-manager/packages/common.nix`
- Gui-only → `home-manager/packages/desktop.nix`
- From unstable → prefix with `pkgs-unstable.`

### Add a home-manager program module

- Shared → drop under `home-manager/modules/common/…` and register in `common/default.nix`
- Gui-only → `home-manager/modules/desktop/…` and register in `desktop/default.nix`

### Add a NixOS module

- Shared → `modules/common/…` and register in `common/default.nix`
- Gui-only → `modules/desktop/…` and register in `desktop/default.nix`

### Add a new host

1. Append a row to `hosts` in `flake.nix`.
2. Create `hosts/<hostname>/configuration.nix` (copy the closest existing).
3. Physical: generate `hardware-configuration.nix`, add module under `modules/hardware/`.
4. First rebuild explicit: `sudo nixos-rebuild switch --flake .#<hostname>`.
