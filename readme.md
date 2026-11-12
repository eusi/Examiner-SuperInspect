# Examiner
> **An Advanced Inspection Addon**

With Examiner, you can inspect other players' gear, stats, item level/gearScore, talents, pvp details, achievements, guild information, professions, glyphs and runes in one convenient window. Mouseover shortcuts, gear comparisons and a searchable inspection cache make inspecting players quick and comfortable.

## Installation

- **Automatic:** Install via [CurseForge](https://www.curseforge.com/wow/addons/examiner-classic-sod)
- **Manual:** Download the addon ZIP from [GitHub Releases](https://github.com/eusi/Examiner-SoD-/releases), extract the `Examiner` folder into your WoW client's `Interface/AddOns`. Then restart WoW and enable Examiner in **AddOns**.

## Features

- **Gear overview:** Equipped items, item levels, GearScore, and combined gear stats.
- **3D model:** Rotate, move, and zoom, even NPCs and player from other faction.
- **Inspect keybindings:** Inspect mouseover, your target, and yourself.
- **Talents:** Interactive trees and spell tooltips. Retail/Forever build exports and Wowhead links.
- **PvP:** Honor, kills, ranks, arena/rated records, and rank progress.
- **Player cache:** Keep inspected gear and optional talent, glyph, PvP, guild, and profession snapshots for later; search, filter, and sort saved players.
- **Guilds:** Guild details and crests where available.
- **Achievements:** Completion dates, points, and rewards (Retail/Mists).
- **Professions:** Shows profession skill levels (Forever).
- **Runes:** Equipped runes across all Season of Discovery phases (SoD).
- **Glyphs:** Major and minor glyphs in the Talents tab, including empty and locked slots (Mists).
- **Auto-inspect:** Follow target changes while Examiner is open.
- **Modules:** Enable/disable modules and tabs. Modules unavailable in your WoW version are greyed out.
- **Gear comparison:** Stat differences between players or individual items.
- **Settings:** Movable, scalable, item-level, tooltip, caching options, font via LibSharedMedia support, and more.
- **Appearance:** Classic, Modern, and Forever styles. Bottom icon menus by default; text and right-side icon menus remain available.
- **11 translations:** enUS, deDE, frFR, esES, esMX, itIT, ptBR, koKR, ruRU, zhCN, zhTW.

Features depend on the client and available inspect data.

![Examiner screenshots](https://github.com/user-attachments/assets/ce5fcfd7-b708-41de-8b65-bfaf9b6ae6fb)

**Supported versions:** Retail, Forever, Classic Era, Hardcore, Season of Discovery, TBC Classic, and Mists of Pandaria Classic.

## Quick start

- **Inspect** through the player's unit menu or via `/ins [unit]`.
- Assign shortcuts under **Key Bindings > Examiner** if needed.
- Only gear is **cached** by default. Enable optional caching under **More > Settings**.

## Controls

- **Gear comparison:** Shift-left-click **Stats** to mark a reference; Shift-right-click to clear it.
- **Cache filters:** Open **More > Cached Players**, then right-click **More** and choose **Set Filter...**. Examples: `1-79`, `class:deathknight`, `class:hunter guild:awesome`.
- **Model:** Left-drag to rotate, right-drag to move, scroll to zoom. Ctrl-left-click changes the background; Ctrl-right-click toggles it; Shift-left-click resets the model.
- **Gear List:** Enable it under **More > Modules** (disabled by default).
- **Style / menu:** Choose these independently under **More > Settings**.

## Commands

`/ex` or `/examiner` lists commands. Both prefixes work with the following:

| Command | Action |
| --- | --- |
| `/ex inspect [unit]` or `/ins [unit]` | Inspect `target`, `player`, `focus`, `party3`, etc. Defaults to your target, or yourself without a target. |
| `/ex si <itemLink>` | Print an item's gear stats. |
| `/ex compare <itemLink1> <itemLink2>` | Print item stat differences. |
| `/ex scale <value>` | Window scale: `0.75`–`1.50`; default `1.00`. |
| `/ex reset` | Center the window when **Make Examiner Movable** is enabled in Settings. |
| `/ex clearcache` | Delete all cached inspection data. |

## History & Credits

I took over and rebuilt Aezay's original Examiner in 2024, followed by another major overhaul in 2026, while keeping the original idea.

- Aezay, the original author of Examiner.
- Chester, the original author of SuperInspect, who gave me the idea to make this mod.
- Haldamir of Gorgonnash, for the German translation.
- Qcat0214, who made the Chinese translation for the 1.13.2 patch.
- omosiro, who made the Korean translation.
- chkid, for Korean translation update for the 1.13.2 patch.
- g3gg0, changes to the German translation & author to one of the SuperInspect versions.
- Pettigrow of Sinstralis, for the translation to French.
- Siphony of EU-Onyxia, updated German translation.
- Dridzt, for some of the required changes in the WotLK to make it function properly again.
- quicksylver, for updating the English patterns to WotLK.
- Darigaaz of SoulFlayer(RU) for the Russian translation.
- Hoofik of AshenVale for the 3.0 patch update of the Russian translation.
- Maxfunkey (aka Carambha of EU-Lordearon), patch 3.0.2 update of the German and Frensh translation.
- Thorakon (aka Pulgrim of EU-Alexstrasza), for the patch 3.0.3 update of the German translation.
- ericyen, for the Taiwan translation for the 3.1 release.
- eusi, for the updated talent module in Mists of Pandaria.
- ywfn, for making the PvP module work with all pvp and battleground changes.
- fallendos, for an update to the Korean patterns.
- Netrox, for the help in updaing the talents module for WoD.
- Cidrei, updates to the GetUpgradedItemLevel lib to fix itemLevels for Timewarped items.
- Valmere for ZG enchants and more.
- vanillalad for Details talents implementation and AQ enchant (enUS).
- All the people using Examiner!

Cheers,
sAks/eusi
