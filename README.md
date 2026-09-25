# Omarchy Workspace Dots

An animated Quickshell bar widget for Omarchy Quattro. The focused workspace grows into a pill while the previous one shrinks; the dots move together as the strip changes shape.

![Workspace Dots preview: the third workspace is focused](preview.png)

## Requirements

- Omarchy Quattro with its Quickshell plugin bar and a running `omarchy-shell` session; this is not a Waybar module.
- `git`, `jq`, and `hyprctl` on `PATH` (checked before installation). No `sudo`, AUR package, extra font, or system-file changes.

## Install

Clone [voyagen/oma-dots](https://github.com/voyagen/oma-dots):

```sh
git clone https://github.com/voyagen/oma-dots.git
cd oma-dots
./install.sh
```

Confirm the new dots render and can focus a workspace **before** removing the old indicator. Omarchy's plugin list reports layout membership, not whether asynchronous QML loading succeeded. Then run:

```sh
./install.sh --replace omarchy.workspaces
```

Replace `omarchy.workspaces` with the **ID currently present** in your `~/.config/omarchy/shell.json` bar layout if you use a different workspace widget, including a custom `type: "qml"` or `type: "command"` entry. The installer saves that complete entry and its position before disabling it. It refuses an absent or duplicated ID, a changed layout, and an existing plugin checkout with a different manifest. To keep both indicators, omit the second step; no prior widget will be restored on uninstall.

If you already installed the earlier `voyagen.workspaces-dots` plugin, use `./install.sh --replace voyagen.workspaces-dots` while that widget is still present in the bar. This keeps its files intact for rollback; `./uninstall.sh` restores its old ID and settings. Do not remove the old directory until you no longer need that rollback.

Installation uses Omarchy's Git-backed `plugin add` command, waits for asynchronous discovery, and only then enables the new widget. Re-running `./install.sh` leaves existing widget files and bar placement unchanged. The installer writes restore state to `~/.config/omarchy/.voyagen.oma-dots.restore.json`, and backs up an existing `shell.json` before replacing a widget. If replacement is interrupted after that state is saved, run `./uninstall.sh` to recover. For a checkout not yet published upstream, use `./install.sh --source "$PWD"` to install its committed Git revision, then run the same `--replace` step after verifying the bar.

To update an installed Git checkout:

```sh
./install.sh --update
```

This refuses local changes rather than overwriting them. On Omarchy versions without the Quickshell plugin commands, installation fails without altering system files. Omarchy itself uses `$HOME/.config/omarchy/` for shell configuration; a different `XDG_CONFIG_HOME` does not relocate that directory.

## Usage

The bar shows workspaces 1 through the highest occupied or focused workspace, up to 10. Empty workspaces in between keep their dots, so a window on workspace 3 gives you dots for 1, 2, and 3. An empty focused workspace is shown too.

Click a dot to focus its workspace. The active indicator is a 16 px pill; inactive indicators are 8 px circles, with a 6 px gap. The 90 ms grow/shrink animation also moves neighboring dots. Colors follow the active Omarchy theme, and the widget supports horizontal and vertical bars.

## Validate

```sh
omarchy plugin validate .
```

## Remove

From the checkout:

```sh
./uninstall.sh
```

It refuses to discard local changes in a Git-managed plugin, removes the plugin through Omarchy, then restores the recorded previous entry while preserving unrelated bar changes. If the previous entry was re-added with different content, it refuses to overwrite that entry. If the plugin was installed outside this installer, there is no restore state: removal leaves the rest of the bar alone; restore your previous widget from your own backup.

## Compatibility

The manifest ID and QML `moduleName` are both `voyagen.oma-dots`. The widget shows numbered Hyprland workspaces 1–10. Special workspaces and workspace IDs above 10 have no highlighted dot. Each monitor's bar shows the same global focused workspace, matching Omarchy's built-in workspace widget. Clicking a dot uses Omarchy's `hl.dsp.focus` dispatcher, which must remain available in a customized Hyprland configuration. A future Omarchy update that changes its Quickshell widget API or Hyprland dispatcher will require an updated plugin; Git-backed installs can receive that update with `./install.sh --update`. Plugin updates do not automatically incorporate changes to Omarchy's default `shell.json` into an existing user config.
