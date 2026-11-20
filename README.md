# Examiner
> **An Advanced Inspection Addon**

With Examiner, you can inspect other players' gear, stats, item level/GearScore, talents, PvP details, achievements, guild information, professions, glyphs and runes in one convenient window. Mouseover shortcuts, gear comparisons and a searchable inspection cache make inspecting players quick and comfortable.

Originally developed by Aezay, Examiner has been maintained and extensively enhanced by me since 2024.

**Recent Enhancements (2026):**

- **UI Overhaul**: New themes, scaling and customizations.
- **Compatibility**: Supports all WoW versions, incl. Retail, Forever, Classic.
- **New Modules**: Professions, Player Actions, Achievements, SoD Runes, Glyphs.
- **Gear & Stats**: GearScore, improved stats and new gear list.
- **Talents & PvP**: Enhanced talent trees and PvP stats.
- **Player Cache**: Advanced search, filtering and sorting.

[*Full Changelog*](https://github.com/eusi/Examiner-SuperInspect/blob/master/CHANGELOG.md)

## Installation

- **Automatic:** Install via [CurseForge](https://www.curseforge.com/wow/addons/examiner-superinspect), [WoWInterface](https://www.wowinterface.com/downloads/fileinfo.php?id=26695#info), or [Wago](https://addons.wago.io/addons/examiner-superinspect-forever-retail-classic-sod).
- **Manual:** Download the addon ZIP from [GitHub Releases](https://github.com/eusi/Examiner-SuperInspect/releases), extract the `Examiner` folder into your WoW client's `Interface/AddOns`. Then restart WoW and enable Examiner in **AddOns**.

<br>
<br>

![Examiner screenshots](https://github.com/user-attachments/assets/ce5fcfd7-b708-41de-8b65-bfaf9b6ae6fb)

**Supported versions:** Retail, Forever, Classic Era, Hardcore, Season of Discovery, TBC Classic, and Mists of Pandaria Classic.

## Features

- **Gear overview:** Equipped items, item levels, GearScore, and combined gear stats.
- **3D model:** Rotate, move, and zoom - even NPCs and players from the opposite faction.
- **Inspect keybindings:** Inspect mouseover, your target, and yourself.
- **Talents:** Interactive trees and spell tooltips. Retail/Forever build exports and Wowhead links.
- **PvP:** Honor, kills, ranks, arena/rated records, and rank progress.
- **Player cache:** Save inspections for later; search, filter, and sort saved players.
- **Guilds:** Guild details and crests where available.
- **Achievements:** Completion dates, points, and rewards (Retail/Mists).
- **Professions:** Shows profession skill levels (Forever).
- **Runes:** Equipped Season of Discovery runes (SoD).
- **Glyphs:** Major and minor glyphs (Mists).
- **Auto-inspect:** Follow target changes while Examiner is open.
- **Modules:** Enable/disable modules and tabs.
- **Player actions:** Add friends, invite players to your group, or open a whisper.
- **Gear List:** A compact list of all items with item levels and an overall score.
- **Gear comparison:** Stat differences between players or individual items.
- **Settings:** Customize window size and position, item-level, tooltip, caching options, and more.
- **Appearance:** Multiple themes, LibSharedMedia fonts, and text or icon menus.
- **11 translations:** enUS, deDE, frFR, esES, esMX, itIT, ptBR, koKR, ruRU, zhCN, zhTW.

Features depend on the client and available inspect data.

## Quick start

- **Inspect** through the player's unit menu or via `/ins [unit]`.
- Assign shortcuts under **Key Bindings > Examiner** if needed.
- Only gear is **cached** by default. Enable optional caching under **More > Settings**.

## Controls

- **Gear comparison:** Shift-left-click **Stats** to mark a reference; Shift-right-click to clear it.
- **Cache search:** In **More > Cached Players**, click the search icon to filter by name.
- **Cache filters:** In **More > Cached Players**, right-click **More** and choose **Set Filter...**. Examples: `1-79`, `class:deathknight`, `class:hunter guild:awesome`.
- **Model:** Left-drag to rotate, right-drag to move, scroll to zoom. Ctrl-left-click changes the background; Ctrl-right-click toggles it; Shift-left-click resets the model.
- **Gear List:** It is disabled by default. Enable it under **More > Modules**.
- **Style / menu:** Choose these independently under **More > Settings**.
- **Player actions:** Show or hide under **More > Settings > Show Player Actions**.

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

## Support

Report bugs or suggest features in [GitHub Issues](https://github.com/eusi/Examiner-SuperInspect/issues).

## History & Credits

I took over and rebuilt Aezay's original Examiner from taxidriveer in 2024, followed by another major overhaul in 2026, while keeping the original idea.

- Aezay, the original author of Examiner.
- taxidriveer, who took over from Aezay in 2019.
- Chester, the original author of SuperInspect, who gave me the idea to make this mod.
- Haldamir of Gorgonnash, for the German translation.
- Qcat0214, who made the Chinese translation for the 1.13.2 patch.
- omosiro, who made the Korean translation.
- chkid, for the Korean translation update for the 1.13.2 patch.
- g3gg0, changes to the German translation & author to one of the SuperInspect versions.
- Pettigrow of Sinstralis, for the translation to French.
- Siphony of EU-Onyxia, updated German translation.
- Dridzt, for some of the changes required to make Examiner work properly again in WotLK.
- quicksylver, for updating the English patterns to WotLK.
- Darigaaz of SoulFlayer(RU) for the Russian translation.
- Hoofik of AshenVale for the 3.0 patch update of the Russian translation.
- Maxfunkey (aka Carambha of EU-Lordearon), patch 3.0.2 update of the German and French translations.
- Thorakon (aka Pulgrim of EU-Alexstrasza), for the patch 3.0.3 update of the German translation.
- ericyen, for the Taiwan translation for the 3.1 release.
- eusi, for the updated talent module in Mists of Pandaria.
- ywfn, for making the PvP module work with all pvp and battleground changes.
- fallendos, for an update to the Korean patterns.
- Netrox, for the help in updating the talents module for WoD.
- Cidrei, updates to the GetUpgradedItemLevel lib to fix itemLevels for Timewarped items.
- Valmere for ZG enchants and more.
- vanillalad for Details talents implementation and AQ enchant (enUS).
- All the people using Examiner!

Cheers,
sAks/eusi
