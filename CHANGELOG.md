# Changelog

## Unreleased

- The settings window no longer shows the developer check of the selected recipe; type `/ccolors debug` for it when reporting a bug (`/ccolors check` still works).
- Turning the colours off no longer leaves a recipe stuck in its mouse-over colour.

## v0.3.0 (2026-11-18)

- Settings: an AI help button copies a description of every setting for an AI assistant, and `/ccolors apply` runs the commands it gives back.
- Chat commands now follow one pattern across all EverlookDB addons: `/ccolors help` (or `?`) lists them. New short name `/ccolors` (`/craftcolors` still works); `/ccolors on`, `off` and `toggle` for the colouring; `get` and `set <setting> <value>`; `search <words>`; `status` and `version`; `/ccolors reset` asks first (type it again within 10 seconds); a mistyped command suggests the nearest one.
- The settings window has a search box at the top: type to find any setting.

## v0.2.0 (2026-11-17)

- `/craftcolors` opens a settings window: turn the colouring off, pick your own colour for each difficulty, how much the row under the mouse brightens, and what the game says about the selected recipe. CraftColors also has an entry in the game's Settings > AddOns that opens it. Every setting works from chat too (`/craftcolors orange ff8040`, `/craftcolors settings`, `/craftcolors help`). The old recipe check is `/craftcolors check`; the feedback link opens in CraftColors' own small window.
- `/craftcolors feedback` shows a link for reporting bugs and ideas.
- Turning "Colour recipe names" off now puts the game's own colours back right away.
- Settings window: Escape closes an open dropdown list first, then the window; Escape in a text box puts the old text back; a number typed next to a slider snaps to the slider's steps; a Delete or Reset that asks for a second click no longer forgets it early.
