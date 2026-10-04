---
name: muthur-theme
description: Use when adding or changing a color preset (theme) of the muthur shell — designing the 16-color palette, checking its contrast, adding it to ThemeStore.qml, and generating its four wallpapers at the same time.
---

# Adding a muthur color preset

A preset is one entry in `builtinPresets` in
`dotfiles/quickshell/muthur/ThemeStore.qml`. Everything else follows from
it: the shell, fuzzel, labwc, alacritty, Neovim, btop, GTK and Firefox are
regenerated from it when it's applied, and every preset has **four
wallpapers of its own** that the LOOK tab offers beside its name. A preset
is finished only when all of these are done:

1. the palette, designed and contrast-checked;
2. the entry in `ThemeStore.qml`;
3. **its four wallpapers, generated in the same step** (`wallpapers/themed.py <key>`);
4. the README updated;
5. checked in `[SYS] > [LOOK]`.

Never leave a preset without its wallpapers: the LOOK tab shows no
sketches for it, and clicking it keeps whatever wallpaper was there. And
never change one preset's colors without regenerating its wallpapers.

## 1. The palette

The entry's shape (pywal's `colors.json` shape, so a wallpaper-derived
palette loads the same way):

```qml
// One or two lines on the idea: where the colors come from, what the
// accent is for.
{ key: "corpoCarbon", name: "CORPO CARBON",
  special: { background: "#2b2d30", foreground: "#c9ccd0", cursor: "#a3b6c8" },
  colors: { color0: "#35383c", color1: "#d48a8a", color2: "#8fb08a", color3: "#c8b47a",
            color4: "#86a2c4", color5: "#ad95c3", color6: "#7fb2b5", color7: "#c9ccd0",
            color8: "#83888f", color9: "#e0a0a0", color10: "#a6c49f", color11: "#dac793",
            color12: "#a0b8d6", color13: "#c2aed4", color14: "#9ac7c9", color15: "#e8eaec" } },
```

- `key` is camelCase and unique (it names the wallpaper folder); `name`
  is the uppercase label shown in LOOK.
- The shell's own four colors derive from it: background, foreground
  (the **main color** — text, and the wallpapers' main color), dim =
  `color8` (inactive things, the wallpapers' line color), focus =
  `cursor` (the accent).
- The twelve hue slots (`color1..6`, `color9..14`, ANSI order: red,
  green, yellow, blue, magenta, cyan) are **muted and pulled toward the
  theme's base** so terminals and the editor stay in one mood instead of
  turning rainbow — but they must stay distinguishable: diagnostics and
  diffs still have to tell red from green.
- `color2` and `color3` matter more than the rest: they're the 3rd and
  4th colors of the swatch in LOOK (which shows `color0..3`) and the
  wallpapers' second and third colors. Make them read as part of the
  theme's identity.
- Dark or light is decided by the background's HSL lightness (> 0.5 is
  light); it picks the group in LOOK and the GTK/Firefox variant. In a
  **light** preset the slots run the other way: `color0` is the lightest
  (near the background), `color7` a mid grey, `color15` the darkest
  (see E-INK, NOSTROMO, CORPO CARBON LIGHT).
- Easy on the eyes: a dark background that isn't pure black, a light one
  that isn't pure white, text that isn't pure white/black either.

Check it before going further:

```sh
.claude/skills/muthur-theme/check-palette.py <key>     # or --all
```

It prints the WCAG contrast of the foreground, focus, dim and hue slots
against the background and flags what falls under these floors:
**foreground 7:1, focus 4.5:1, dim 3:1, hue slots 4.5:1** (`color0/7/8/15`
are structural, not checked). A preset meant for work (like Corpo Carbon)
should pass all of them; a stylized one may knowingly dip a hue slot,
but never the foreground. Adjust the colors (lighter on dark, darker on
light) until the report says OK, or agree on the exceptions with the
user.

## 2. The entry

Add it to `builtinPresets` (order within the list sets the order within
its DARK/LIGHT group; new ones go at the end), with the short comment
above it like the others. Save: Quickshell hot-reloads, and the preset
appears in LOOK. **Don't apply it to check it** without asking — applying
rewrites the configs of the user's whole desktop (alacritty, Neovim,
GTK, Firefox...) and replaces their current theme.

## 3. Its four wallpapers — always, right away

```sh
wallpapers/themed.py <key>
```

Draws the four designs into
`~/.local/share/muthur-shell/wallpapers/<key>/` (3440x1440, about 3 s and
2 MB per preset): `1-grid`, `2-topo`, `3-horizon`, `4-dots`. They take
their colors from the entry — main = foreground, second and third =
`color2`/`color3` (skipping one that repeats the main color or is grey),
lines = `color8`, details = `cursor` — and stay quiet: low contrast,
almost no text (only the preset's name, small, on TOPO).

Look at them at full size before calling it done — a contact sheet
shrinks them to nearly nothing, so crop 1:1 instead:

```sh
P=~/.local/share/muthur-shell/wallpapers/<key>
for f in 1-grid 2-topo 3-horizon 4-dots; do magick $P/$f.png -crop 1100x460+1170+760 +repage "$S/c-$f.png"; done
magick "$S"/c-*.png -background "#666" -splice 0x6 -append "$S/preview.png"
```

If the four designs themselves change (in `themed.py`), regenerate
**every** preset (`wallpapers/themed.py`, about a minute) and keep the
LOOK sketches in step: they're `wallpaperLayouts` in `ThemeStore.qml`
(path data in a 100x100 box, drawn by `WallpaperLayout.qml`).

## 4. README

In the LOOK paragraph of `README.md`: the preset count in words (in two
places: the intro line "… palettes" and "… color presets") and the list
of names.

## 5. Check in LOOK

Open `[SYS] > [LOOK]` (or a temporary hook, see the muthur-shell-dev
skill — the bar may only be on the main display, `ThemeStore.mainScreen`)
and look at the new row: four swatch colors, the name, and four sketches
on the right in the preset's colors. The tab rescans the wallpaper folder
each time it opens. Then let the user click it to try it.
