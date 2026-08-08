# What to Explore Next

A personal roadmap for learning and improving this NixOS setup,
roughly ordered from "do this soon" to "when you're ready to go deeper".

---

## 1. Configure Niri (do this first after switching)

Niri's config file lives at `~/.config/niri/config.kdl`.
It doesn't exist by default — Niri ships a built-in default that works
out of the box, but you'll want to customize it quickly.

**Start here:** https://github.com/YaLTeR/niri/wiki/Configuration:-Overview

**Things to configure in config.kdl:**
```kdl
// Set your terminal (used when you press the default keybind)
prefer-no-csd  // ask apps to draw without their own titlebars

binds {
    Mod+T { spawn "foot"; }          // open terminal
    Mod+Space { spawn "fuzzel"; }    // open app launcher
    Mod+Q { close-window; }
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Shift+Left  { move-column-left; }
    Mod+Shift+Right { move-column-right; }
}

output "eDP-1" {
    // Your laptop screen — set resolution/scale here
    scale 1.5   // good for 1080p laptop screens at normal viewing distance
}
```

**Manage it declaratively:** Instead of editing the file manually,
you can add it to home.nix:
```nix
xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;
```

---

## 2. Customize Noctalia

Noctalia's config is managed by home-manager (`programs.noctalia.settings`
in home.nix). It writes the TOML config file to `~/.config/noctalia/`.

**Documentation:** https://docs.noctalia.dev/v5/

**Things to explore:**
- Change the built-in theme (`builtin = "Nord"`, `"Gruvbox"`, `"Dracula"`)
- Try `source = "wallpaper"` to auto-generate a palette from your wallpaper
- Customize which widgets appear on the bar
- Configure the dock and launcher
- Set up custom keyboard shortcuts for the control center

---

## 3. Add a Proper App Launcher

The NNN stack doesn't include a launcher by default (Noctalia has one built in,
but you may want a standalone one for keybind use).

**fuzzel** — the go-to Wayland launcher for Niri users:
```nix
# In development.nix or home.nix
environment.systemPackages = with pkgs; [ fuzzel ];
```
Then bind `Mod+Space` to `fuzzel` in your niri config.

---

## 4. Explore Home Manager Options

Home Manager can declaratively manage almost any dotfile or user-level config.
You're barely scratching the surface right now.

**Search all available options:**
```bash
man home-configuration.nix
# or browse online:
# https://nix-community.github.io/home-manager/options.xhtml
```

**Useful things to try:**
```nix
# Shell — switch to zsh or fish
programs.zsh.enable = true;
programs.fish.enable = true;

# Neovim — fully configured in Nix
programs.neovim = {
  enable = true;
  plugins = with pkgs.vimPlugins; [ telescope-nvim nvim-treesitter ];
};

# Alacritty / foot terminal config
programs.foot = {
  enable = true;
  settings.colors.alpha = 0.9;  # transparent background
};

# GTK theme — set dark mode system-wide
gtk = {
  enable = true;
  theme.name = "adw-gtk3-dark";
};
```

---

## 5. Learn the NixOS Module System

Understanding how modules work makes everything else click.

**Key concepts to learn:**
- `options` vs `config` — modules can define their own options
- `lib.mkDefault` / `lib.mkForce` / `lib.mkOverride` — controlling merge priority
- `lib.mkIf` — conditional config (`if this option is enabled, then set...`)
- `lib.mkMerge` — explicitly merge multiple attrsets

**Try writing your own simple module:**
```nix
# modules/my-aliases.nix
{ ... }:
{
  environment.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake /etc/nixos#victus";
    hms = "home-manager switch --flake /etc/nixos#harua";
  };
}
```
Then import it in configuration.nix. That's all it takes.

**Good reading:** https://nixos.org/manual/nixos/stable/#sec-writing-modules

---

## 6. Flakes — Go Deeper

You're already using Flakes, but there's more to explore.

**Things to try:**
```bash
# See exactly what your flake provides
nix flake show /etc/nixos

# Inspect a package before installing
nix show-derivation nixpkgs#firefox

# Open a temporary shell with a package (no install needed)
nix shell nixpkgs#cowsay --command cowsay "hello"

# Run a program without installing it at all
nix run nixpkgs#cowsay -- "hello"
```

**Flake outputs you can add later:**
- `devShells` — per-project development environments (`nix develop`)
- `packages` — build your own software with Nix
- `overlays` — patch or override nixpkgs packages

---

## 7. Nix Development Shells (`nix develop`)

Instead of installing everything globally in development.nix, you can
create per-project shells with exactly the tools that project needs.

**Add to flake.nix:**
```nix
devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
  packages = [ pkgs.nodejs pkgs.postgresql ];
};
```

Then `cd` into your project and run `nix develop` — you're in a shell
with those tools. Leave the shell and they're gone. No global pollution.

**direnv integration** (enters the shell automatically when you `cd` in):
```nix
# In home.nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
};
```

---

## 8. Improve the Gaming Setup

You have Steam + Lutris + Heroic + Proton + MangoHud already.
Next steps for gaming:

- **Proton-GE:** Use `protonup-qt` (already installed) to install
  Proton-GE for better game compatibility than stock Proton.

- **GameMode:** Optimizes CPU scheduling and governor when a game runs:
  ```nix
  programs.gamemode.enable = true;
  ```

- **MangoHud config:** Customize the overlay in `~/.config/MangoHud/MangoHud.conf`
  — control which stats show up (FPS, GPU temp, VRAM usage, etc.)

- **gamescope:** Already installed — useful for upscaling games or locking
  framerate: `gamescope -W 1920 -H 1080 -r 60 -- %command%`

---

## 9. Secrets Management

Right now PostgreSQL uses `trust` auth (no passwords) which is fine for
localhost-only dev. If you ever expose services or add sensitive config
(API keys, passwords), look into:

- **agenix** — encrypts secrets with your SSH key, decrypts on rebuild:
  https://github.com/ryantm/agenix

- **sops-nix** — alternative using `sops` + age/GPG encryption:
  https://github.com/Mic92/sops-nix

Both let you commit encrypted secrets to git safely and have them
available to NixOS services at build time.

---

## 10. Explore the NixOS Option Search

The fastest way to discover what NixOS can configure declaratively:

- **Online search:** https://search.nixos.org/options
- **Package search:** https://search.nixos.org/packages
- **Home Manager options:** https://nix-community.github.io/home-manager/options.xhtml

**In the terminal:**
```bash
# Search NixOS options
nixos-option services.postgresql

# Show current value of any option
nixos-option networking.hostName
```

---

## Quick Reference: Where to Add Things

| I want to...                              | Edit this file                        |
|-------------------------------------------|---------------------------------------|
| Install a new app for all users           | `modules/development.nix`             |
| Install a personal app just for harua     | `users/harua/home.nix`                |
| Change a system service                   | `hosts/victus/configuration.nix`      |
| Change desktop/Wayland settings           | `modules/desktop/nnn.nix`             |
| Configure Noctalia theme/widgets          | `users/harua/home.nix`                |
| Configure Niri keybinds/layout            | `~/.config/niri/config.kdl`           |
| Add a new flake dependency                | `flake.nix`                           |
| Configure audio                           | `modules/audio.nix`                   |
| Fix GPU/display issues                    | `modules/nvidia.nix`                  |
| Add a Flatpak app                         | `modules/flatpak.nix`                 |
| Add a shell alias                         | `users/harua/home.nix` (shellAliases) |
