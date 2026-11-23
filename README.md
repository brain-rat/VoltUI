# VoltUI

A flat, dark UI overhaul for **World of Warcraft: Forever** (client 1.60, Interface 16001): unit frames, its own party and raid frames, nameplates, action bars, bags and bank, tooltips, minimap, a world map with zone levels and coordinates, and one settings window for all of it.

**Project page:** https://brain-rat.github.io/VoltUI/

| Folder | What it is |
|---|---|
| [`VoltUI`](VoltUI/README.md) | The add-on. One flat, dark style for the game's windows: player and target frames with cast bars, its own party and raid frames with separate settings for each (size, layout, power bars, overhealing, debuffs you can remove first, a heal mode with click-casting, your HoTs with timers, dispel windows and a dispel warning), the game's nameplates restyled with their own settings, fully customisable action bars, bags and bank with categories and a rarity glow on items, loot window, tooltips, a square minimap you can move and scale, a world map with zone levels and coordinates, junk selling at vendors, and a skin for Questie if you have it. |
| [`tools`](tools) | Scripts that draw VoltUI's art and make the release zip. |
| [`tests`](tests) | A stubbed WoW environment that loads VoltUI outside the game, and the release tool's test. |

## Install

1. Download the latest release zip from the [Releases](../../releases) page.
2. Copy the `VoltUI` folder into `World of Warcraft\_forever_\Interface\AddOns`. Keep the folder's name as it is: your saved settings are tied to it.
3. Restart the game. `/volt` opens the settings.

If you use [Questie](https://github.com/Questie/Questie) for quests, VoltUI restyles it to match.

## Data

- **VoltUI ships no game data of its own** beyond Classic's zone level ranges and a few for Forever's new zones (in `VoltUI/WorldMap.lua`), and no tools that make any.
- **QuestieDB.** VoltUI can read the separate QuestieDB add-on while the game runs, for each quest's items in your bags. Nothing of it is copied into this repository.
- **Questie.** Nothing of Questie's is in this repository. VoltUI only restyles its windows while the game runs.
- **Your own play.** Your settings and what VoltUI notes (the error list, say) stay in VoltUI's saved variables on your PC.
- **Other add-ons.** VoltUI's world map, tooltips, settings window, minimap menu and moving frames have hooks another add-on can use to add parts and data of its own (see *For other add-ons* in [VoltUI's read-me](VoltUI/README.md#for-other-add-ons)).

## Building

- **Art:** `tools/make_bars.py`, `make_hatch.py`, `make_round.py` and `make_bolt.py` draw the bar textures, hatching, rounded corners and the bolt logo in `VoltUI/Media`.

## Releases

`python tools/package.py` makes the release zip in `dist/`, named after the toc's version: just the `VoltUI` folder, with the licence inside it. It takes the files git would commit, and it stops if a file that .gitignore lists, or any file carrying a "not for redistribution" header, gets in, or if the toc loads a file that isn't there. `--list` shows what would go in.

To publish one, set `## Version` in `VoltUI/VoltUI.toc`, commit, then push a tag of that version:

```
git tag v1.2.3
git push origin v1.2.3
```

GitHub then runs every test on Lua 5.1, makes the zip and puts it on a new release (`.github/workflows/release.yml`). It makes no release if a test fails or the tag isn't the toc's version.

## Licence

GPL-2.0 (see [LICENSE](LICENSE)). The bundled fonts in `VoltUI/Fonts` (Barlow, Barlow Condensed, Rajdhani, Chakra Petch, Inter, PT Sans Narrow, Lato, Titillium Web, Teko, Big Shoulders Text, Baloo 2, Orbitron, Russo One, Oxanium, Electrolize, Bai Jamjuree, JetBrains Mono, Space Mono, Bebas Neue, Inconsolata) are under the SIL Open Font Licence; their licences are next to them.

World of Warcraft is a trademark of Blizzard Entertainment. This project is not affiliated with or endorsed by Blizzard, by ForeverDB, or by Questie's authors.

## Tests

`tests/` holds a stubbed WoW environment that loads VoltUI outside the game and checks its behaviour. One command runs everything on real Lua 5.1 (it needs `pip install lupa`): the compile check, VoltUI's tests and every tool's test.

```
python tests/run_all.py
```

Or one at a time. The Lua tests run on any Lua from 5.1 up, but the game runs 5.1, so use that if you can:

```
lua5.1 tests/voltui_test.lua VoltUI
python tests/package_test.py
```

Another add-on built on VoltUI's hooks can run its own tests inside these: `VOLTUI_EXTRA` names its test file. To include the Questie skin, set `QUESTIE_DIR` to a Questie folder. The test then loads Questie's real tracker, settings and AceGUI files.

Newer Lua accepts code the game refuses, and a file that doesn't compile never loads, so its whole feature goes missing. This compiles every add-on file on real Lua 5.1 (it needs `pip install lupa`):

```
python tests/check_lua51.py
```
