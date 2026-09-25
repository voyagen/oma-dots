# Omarchy Workspace Dots

An animated Quickshell bar widget for Omarchy Quattro. The focused workspace grows into a pill while the previous one shrinks; the dots move together as the strip changes shape.

![Workspace Dots preview: enlarged bar widget with workspace two, then three, focused](preview.png)

The marketplace preview illustrates the widget at 3.5× scale. Edit `preview.svg` and regenerate `preview.png` with `rsvg-convert -w 1600 -h 900 -o preview.png preview.svg`.

## Requirements

- Omarchy Quattro with a running `omarchy-shell` session and its Quickshell plugin bar; this is not a Waybar module.
- `hyprctl` for workspace switching (provided by Omarchy). No `sudo`, AUR package, extra font, or system-file changes.

## Install

```sh
omarchy plugin add https://github.com/voyagen/oma-dots.git --enable
```

Check that the dots appear and clicking them switches workspaces. If the old workspace indicator is still on the bar, remove it **after** checking the new one:

```sh
omarchy plugin disable omarchy.workspaces
```

Use the ID of your old indicator instead if it is not `omarchy.workspaces` (for example, `voyagen.workspaces-dots`). Disabling it does not remove its files. The two indicators can also coexist. To move the dots, use `omarchy bar move voyagen.oma-dots --section left --index 1`.

If the dots do not appear after installation, run `omarchy plugin list` to confirm `voyagen.oma-dots` is enabled, then run `omarchy restart shell`. Plugin discovery can leave the running bar stale; restarting it restored the dots without changing the widget. `omarchy plugin validate .` checks the plugin package, not whether the running bar rendered it.

Previous installer versions saved replaced widget settings to `~/.config/omarchy/.voyagen.oma-dots.restore.json`. Native removal does not read that file; restore any custom widget/settings manually if needed.

To update a Git-installed copy:

```sh
omarchy plugin update voyagen.oma-dots
```

## Usage

The bar shows workspaces 1 through the highest occupied or focused workspace, up to 10. Empty workspaces in between keep their dots, so a window on workspace 3 gives you dots for 1, 2, and 3. An empty focused workspace is shown too.

Click a dot to focus its workspace. The active indicator is a 16 px pill; inactive indicators are 8 px circles, with a 6 px gap. The 90 ms grow/shrink animation also moves neighboring dots. Colors follow the active Omarchy theme, and the widget supports horizontal and vertical bars.

## Validate

For a local checkout:

```sh
omarchy plugin validate .
```

## Remove

```sh
omarchy plugin remove voyagen.oma-dots
```

Removal does not restore a workspace indicator that you disabled separately. To put Omarchy's default one back on the bar:

```sh
omarchy plugin enable omarchy.workspaces
```

If you used a different widget, enable or place that widget by its own ID instead.

## Compatibility

The manifest ID and QML `moduleName` are both `voyagen.oma-dots`. The widget shows numbered Hyprland workspaces 1–10. Special workspaces and workspace IDs above 10 have no highlighted dot. Each monitor's bar shows the same global focused workspace, matching Omarchy's built-in workspace widget. Clicking a dot uses Omarchy's `hl.dsp.focus` dispatcher, which must remain available in a customized Hyprland configuration. A future Omarchy update that changes its Quickshell widget API or Hyprland dispatcher will require an updated plugin. Plugin updates do not automatically incorporate changes to Omarchy's default `shell.json` into an existing user config.

## License

MIT. See [LICENSE](LICENSE).
