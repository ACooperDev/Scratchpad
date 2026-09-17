# Scratchpad

A quick note widget for the [Omarchy](https://omarchy.org/) bar. Click the
sticky-note icon, type, click away. Your note is saved and waiting the next time
you open it.

<!-- Add a screenshot here: a bar with the icon, and the open note panel. -->

## Install

```bash
omarchy plugin add https://github.com/ACooperDev/Scratchpad.git
omarchy plugin enable acooper.scratchpad --section center
```

Both steps are needed. `omarchy plugin add` warns you that plugins run as
unsandboxed code inside your shell and installs this one **disabled**, so you can
read the source before it runs. That warning and the widget not appearing until
you run `enable` are both intentional — nothing has gone wrong.

Put it somewhere other than the center with `--section left` or `--section right`.

## Use

| Action | Result |
|---|---|
| Click the icon | Opens the note over whatever is on screen |
| Type | Just type — the panel takes keyboard focus on open, with the cursor at the end of what is already written |
| Click anywhere else | Closes and saves |
| `Esc` | Same |
| **Right-click the icon** | Swaps the note for a size form — see below |

The note also saves on its own one second after you stop typing, so a crash or a
reboot costs you nothing.

## Resizing

Right-click the icon and the card shows `W` and `H` fields instead of your note:

| Key | Does |
|---|---|
| `Tab` | Move between width and height |
| `Enter` | Apply and go back to the note |
| `Esc` | Cancel and go back to the note |

The panel resizes as you type, so you are always looking at the size you are
setting. Right-clicking again backs out without applying. Values are pixels,
clamped to 200–1200 wide and 120–1000 tall, and written to your `shell.json`, so
they survive a restart.

## Your note

Plain text at `~/.local/state/omarchy/scratchpad.txt`. Nothing else touches it —
back it up, symlink it into a notes folder, edit it in `$EDITOR` while the panel
is closed. Changes made outside are picked up the next time the panel opens.

## Settings

Set through the bar, or by right-clicking for width and height:

```bash
omarchy bar set acooper.scratchpad width 420 --json
omarchy bar set acooper.scratchpad notePath ~/notes/scratch.txt
```

Pass `--json` for the numeric settings. Without it `omarchy bar set` stores the
value as a JSON *string* (`"420"` rather than `420`); this plugin copes with
either, but the numbers belong in `shell.json` as numbers.

| Key | Default | What it does |
|---|---|---|
| `notePath` | `~/.local/state/omarchy/scratchpad.txt` | Where the note is stored. `~/` works. |
| `width` | `340` | Panel width in pixels, before UI scaling |
| `height` | `260` | Panel height in pixels, before UI scaling |
| `placeholder` | `Scratchpad` | Greyed-out text shown when the note is empty |

## Requires

Omarchy running the Quickshell-based shell — if `omarchy plugin list` works, you
have it.

## Hacking on it

The files live in `~/.config/omarchy/plugins/acooper.scratchpad/` once installed.

**Run `omarchy restart shell` after every edit.** Saving a plugin file logs
`Local plugin changed, reloading` and `omarchy-shell shell rescanPlugins` returns
cleanly, but a bar widget already mounted in a slot keeps running its old code, so
edits look like they do nothing. Note also that `console.log` from plugin QML does
not reach `journalctl -t omarchy-shell`, though QML errors and warnings do.

## Uninstall

```bash
omarchy plugin remove acooper.scratchpad
```

Your note file is left alone.

## License

MIT — see [LICENSE](LICENSE).
