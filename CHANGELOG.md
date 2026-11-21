# Changelog

## Unreleased
- CraftColors is now part of EverlookDB Crafting: the same colours, skill-up chance and counts, on the "Profession window" page of /ecraft, and your CraftColors settings are carried over. While an EverlookDB Crafting that has them is enabled, CraftColors stands down so the window isn't coloured twice: it says so once when you log in, and /ccolors opens that page. You can then disable CraftColors. Without EverlookDB Crafting, CraftColors works as before. This is CraftColors' last version.
- Fixed: the skill-up % and count were drawn over long recipe names, and the count was said twice next to the game's own "[11]". They now sit after the game's count, and a long name is shortened just enough to make room.

## v0.5.0 (2026-11-20)
- After each yellow and green recipe in the profession window: the chance that one craft raises your skill ("37%", in the recipe's colour). It needs EverlookDB Crafting, which knows each recipe's yellow and gray skill; without it the names are only coloured.
- After each recipe: how many you can make from your bags ("(4)"). Turn on "Also count my bank and other characters" to see how many more ("(4 +5)"). Where the game already shows the number after the name, it isn't said twice.
- New settings for both, in /ccolors.

## v0.4.0 (2026-11-20)
- Settings window: switches, buttons and sliders use a softer shade of the accent colour, an on switch has a dark knob so it stands out, and boxes have cleaner rounded edges.

- The settings window no longer shows the developer check of the selected recipe; type `/ccolors debug` for it when reporting a bug (`/ccolors check` still works).
- Turning the colours off no longer leaves a recipe stuck in its mouse-over colour.
- Recipe names are also coloured if a profession opens in the older-style trade skill or craft window instead of the usual profession window.

## v0.3.0 (2026-11-18)

- Settings: an AI help button copies a description of every setting for an AI assistant, and `/ccolors apply` runs the commands it gives back.
- Chat commands now follow one pattern across all EverlookDB addons: `/ccolors help` (or `?`) lists them. New short name `/ccolors` (`/craftcolors` still works); `/ccolors on`, `off` and `toggle` for the colouring; `get` and `set <setting> <value>`; `search <words>`; `status` and `version`; `/ccolors reset` asks first (type it again within 10 seconds); a mistyped command suggests the nearest one.
- The settings window has a search box at the top: type to find any setting.

## v0.2.0 (2026-11-17)

- `/craftcolors` opens a settings window: turn the colouring off, pick your own colour for each difficulty, how much the row under the mouse brightens, and what the game says about the selected recipe. CraftColors also has an entry in the game's Settings > AddOns that opens it. Every setting works from chat too (`/craftcolors orange ff8040`, `/craftcolors settings`, `/craftcolors help`). The old recipe check is `/craftcolors check`; the feedback link opens in CraftColors' own small window.
- `/craftcolors feedback` shows a link for reporting bugs and ideas.
- Turning "Colour recipe names" off now puts the game's own colours back right away.
- Settings window: Escape closes an open dropdown list first, then the window; Escape in a text box puts the old text back; a number typed next to a slider snaps to the slider's steps; a Delete or Reset that asks for a second click no longer forgets it early.
