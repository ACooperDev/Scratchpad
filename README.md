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
| Type | Just type — the panel takes keyboard focus on open |
| Click anywhere else | Closes and saves |
| `Esc` | Same |

The note also saves on its own one second after you stop typing, so a crash or a
reboot costs you nothing.

## Your note

Plain text at `~/.local/state/omarchy/scratchpad.txt`. Nothing else touches it —
back it up, symlink it into a notes folder, edit it in `$EDITOR` while the panel
is closed. Changes made outside are picked up the next time the panel opens.

## Settings

```bash
omarchy bar set acooper.scratchpad width 420
```

| Key | Default | What it does |
|---|---|---|
| `notePath` | `~/.local/state/omarchy/scratchpad.txt` | Where the note is stored. `~/` works. |
| `width` | `340` | Panel width in pixels, before UI scaling |
| `height` | `260` | Panel height in pixels, before UI scaling |
| `placeholder` | `Scratchpad` | Greyed-out text shown when the note is empty |

## Requires

Omarchy running the Quickshell-based shell — if `omarchy plugin list` works, you
have it.

## Uninstall

```bash
omarchy plugin remove acooper.scratchpad
```

Your note file is left alone.

## License

MIT — see [LICENSE](LICENSE).
