# NixOS Config

NixOS + home-manager flake, for desktop or WSL.

## Hosts

| host      | profile | machine                    |
| --------- | ------- | -------------------------- |
| `zenbook` | desktop | Asus UX430UNR              |
| `omen`    | desktop | HP Omen Max 16 (ah0002tx)  |
| `wsl`     | wsl     | WSL2 on Windows (cli only) |

## Structure

```
├── flake.nix                           # inputs, hosts list, per-profile wiring
├── hosts/<host>/configuration.nix      # host entrypoint
│   └── hardware-configuration.nix      # nixos-generate-config output (physical hosts)
├── modules/
│   ├── common/                         # shared NixOS modules
│   ├── desktop/                        # gui-only NixOS modules
│   └── hardware/                       # per-model modules (UX430UNR, 16-ah0002tx, ...)
├── home-manager/
│   ├── packages/{common,desktop}.nix   # home.packages by category
│   ├── profiles/{common,desktop}.nix   # entrypoints (composed by flake)
│   └── modules/
│       ├── common/                     # shared program modules
│       └── desktop/                    # gui-only program modules
└── nvim/                               # nvchad config (git submodule)
```

Profile controls what a host gets:

- `desktop` → `modules/common` + `modules/desktop`, stylix, plasma-manager, spicetify HM modules
- `wsl` → `modules/common` + `nixos-wsl` module

Home-manager always gets `profiles/common.nix`. Desktop profile additionally gets `profiles/desktop.nix` plus the gui-only flake modules.

## Install: physical host

Assumes NixOS is installed and booted.

1. Clone repository

```sh
git clone --recurse-submodules https://github.com/haoren-zhou/nixos-config.git ~/nixos && cd ~/nixos
```

> [!NOTE]
> The `nh` config assumes flake is at `/home/${user}/nixos`

2. Generate hardware config

```sh
mkdir -p hosts/<hostname>   # if <hostname> is new
sudo nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
```

3. If it is a new hardware model, add module under `modules/hardware/` and register host in [flake.nix](./flake.nix)

See [modules/hardware/16-ah0002tx.nix](./modules/hardware/16-ah0002tx.nix) for reference.

Register host in flake by appending to the `hosts` list:

```nix
{
  hostname = "<hostname>";
  profile = "desktop";
  stateVersion = "25.05";
  hardware = "<model>";
}
```

4. Create `hosts/<hostname>/configuration.nix` (copy [hosts/zenbook/configuration.nix](./hosts/zenbook/configuration.nix)).

5. Rebuild

```sh
sudo nixos-rebuild switch --flake .#<hostname>
```

6. Set password and login

```sh
sudo passwd hr # or selected username
su - hr
```

The username must match the value of `user` in [flake.nix](./flake.nix).

If changing usernames, move the flake into the new home directory.

```sh
sudo mv /home/<oldUser>/nixos /home/<newUser>/nixos && sudo chown -R <newUser>:users /home/<newUser>/nixos && cd ~/nixos
```

7. Home-manager switch

```sh
home-manager switch --flake .#<user>@<hostname>
```

8. Reboot

From here, `nh os switch` and `nh home switch` auto-detect the host.

## Install: WSL

**Requirements**: Working [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) installation ([Installation Guide](https://nix-community.github.io/NixOS-WSL/install.html))

Inside the fresh WSL shell (default user is `nixos`):

```sh
# Set a password for the default user so sudo works.
passwd

# Update channels once — required before nixos-rebuild works on a fresh install.
sudo nix-channel --update

git clone --recurse-submodules https://github.com/haoren-zhou/nixos-config.git ~/nixos
cd ~/nixos

# (nixos-wsl docs: `switch` can leave the new user account misconfigured).
sudo nixos-rebuild boot --flake .#wsl
```

Back in PowerShell:

```powershell
wsl --terminate NixOS
wsl -d NixOS --user root   # opens a root shell in the new generation
```

Inside that root shell, set the password, then exit:

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
