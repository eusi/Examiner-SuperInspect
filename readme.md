# Examiner 1.00

Forever Marksmanship has a narrow additional replacement rule for the detached, unspent five-rank Improved Serpent Sting node: the native three-rank Improved Stings node in row 2, column 1 is retained instead. This uses the inspected Hunter specialization/tree context, the native main-tree grid and matching Blizzard icon, not English name matching. Isolation, purchased-rank, edge, choice and metadata guards still apply. Live and cached views use the same rule; other class trees and clients are unchanged.

Forever self-inspection now reads rank, rank points and progress from the same PvP rank faction as Blizzard's PVPRankFrame (`C_MajorFactions.GetMajorFactionProgressionInfo(2800)`). Foreign inspections still use their own inspect response, never personal faction data. Rank updates refresh the current live self view and cache, not foreign players or cached views. Era/SoD now show their supplied rank-progress percentage as a bar too; missing, restricted and invalid progress stays hidden. Missing Classic self APIs no longer fall through to a foreign inspect function. Classic self last-week honor/standing tuple offsets are corrected. Mists now handles delayed personal rated-stat updates like Retail. Retail/Mists/TBC do not gain an unsupported classic rank bar. Settings remain shared, including dropdown behavior, scale slider and translations, and are tested on all six clients.

Forever tree tabs use shorter localized names for spell-school-style labels such as Shadow Magic and Elemental Combat. Green spent-point totals fall back to readable purchased ranks (or displayed ranks on older responses) when the currency summary is missing, but only for a complete tree snapshot. Real zero totals remain visible. The selected tree controls its background, preferring a matching specialization atlas with the matching original talent artwork as fallback; proportions and right alignment are unchanged.

Forever Copy build provides Blizzard's export string, including valid empty low-level builds. Known issue: Forever Copy link still uses an incompatible Wowhead route and can open the wrong class; calculator-link conversion is not implemented. Retail keeps its existing route.

Forever talents use all reported group IDs and native maximum ranks. Only explicitly visible, unique nodes are shown. Detached, unspent copies of a talent already present in the main tree are omitted in live and cached views. The check requires extreme isolation, no incoming/outgoing edges, matching maximum ranks and an unambiguous matching talent (entry/definition/spell identity, or matching name and icon). Matching icons alone never remove nodes; purchased, connected, distinct and ambiguous nodes remain. Native spacing is preserved except for empty gaps exceeding eight node intervals: those are compressed to two intervals so remaining remote nodes cannot shrink the whole tree to a few pixels. `/ex diag talents` reports omitted duplicates, compressed gaps and boundary node coordinates. Icon sizing uses the distance between nodes, not tiny coordinate differences along one axis. Original spell icons are preferred, matching Blizzard's talent display. Available trees stay visible while missing spell metadata loads. Only the named class-tree tabs are shown, including empty trees; there is no generic fourth tab. Older Forever talent snapshots need a fresh inspection (groupingVersion 2), without deleting other cached information. Talent pages consume mouse-wheel input without zooming. The native /ins and /inspect commands open Examiner for the current target.

Mists shows talent-tier unlock levels, specialization role and glyph types. Live talent/glyph tooltips use the inspected character's context; cached views use static spell information. Partial talent replies keep loading and do not replace a complete snapshot. Missing spell metadata can finish loading after the inspect timeout. Classic talent-group selection falls back to the inspected character's active group when a saved selection is unavailable; missing point data is not treated as zero. TBC respects team and teamless arena seasons.

Era/SoD PvP shows the highest reported lifetime rank below the current rank. Classic honor waits participate in the bounded inspect lifecycle; an unanswered request disables an empty page, while late valid data can recover it. Cached rank titles retain foreign names/context. Classic talent-group changes refresh distributed-point summaries and snapshots together. SoD rune mappings are prepared once per equipment scan; existing mappings are retained, but an exhaustive latest-rune coverage audit has not been completed. No unspent talent-point display was added.

Forever's PvP page includes a compact bar under the supplied rank-progress percentage, including cached snapshots. Missing or invalid progress stays hidden. Arena/RBG reads already hide rows for absent APIs or empty replies; a supplied numeric zero remains a real value, not missing data.

Forever tree tabs include supplied spent-point totals from the inspected trait configuration, including cached snapshots. Missing totals stay omitted. The Blizzard average item-level comparison row is enabled for Forever as well as Retail. Cached Forever PvP rank titles use the saved faction and sex; old entries without a faction retain a neutral rank label instead of guessing Horde.

The Retail/Mists achievement tab requests Blizzard's separate comparison data when opened. Completed achievements are sorted newest first, with uncompleted entries below. The footer uses a short label (English: Ach.); the page and tooltip retain the full title. It lists client-enumerated player achievements with completion state, points and descriptive tooltips; progressive stages are deduplicated. Hidden achievements are not guaranteed. The list is built in small batches, is live-only and does not write thousands of entries into SavedVariables. Comparison ownership and target GUID are checked; an already open Blizzard comparison is left untouched.

Standalone inspection with equipment stats, cache and read-only talents. Prepared for Forever, Midnight/Retail, Era/Hardcore, SoD, Mists and optionally TBC through the shared Classic path. In-game acceptance is still required per client; this is not a certified release.

The addon is named **Examiner**. For now, install the working archive as `Interface/AddOns/Examiner_` and disable the other Examiner; do not replace it yet. The working folder uses separate `ExaminerDev_Config / ExaminerDev_Cache` data. Only its temporary `Examiner_.toc` is needed; canonical client manifests use `Examiner_*.toc`, not double underscores. The future `Examiner` installation uses `Examiner_Config / Examiner_Cache`. No other addon is required. Talent viewing never purchases or resets talents. Stats describe equipment contributions, not full character totals; some gem/enchant effects may be unavailable. Missing modern PvP values are hidden, not replaced with invented zeros.

Developer-only `.examiner-tools/`: automated checks (`check.cjs`, `mock-wow.lua`, `smoke.lua`, `reliability.lua`), ZIP packaging (`Build.ps1`), and an explicit library refresh helper (`Sync-Library.ps1`). WoW does not execute these files and the ZIP excludes them. The default build keeps the temporary working folder; `Build.ps1 -Canonical` additionally prepares a future Examiner package without installing or publishing it. In the source checkout, `.examiner-docs/` holds the [current scope, limitations and testing instructions](.examiner-docs/TEST-GESAMTSTAND.md), [changelog](.examiner-docs/CHANGELOG.md), and module API reference. These developer documents are not included in the addon ZIP.

Build output stays inside this project under `.examiner-builds/` (ignored by Git). Do not write outside the project without prior user approval; existing external builds/backups are not modified automatically.

Test dependencies also stay inside the project. From this directory, run `npm ci --prefix .examiner-tools --cache .examiner-tools/npm-cache --ignore-scripts --no-audit --no-fund --update-notifier=false`, then `node .examiner-tools/check.cjs`. Keep `.examiner-tools/package.json` and its lockfile in Git; installed packages/cache are ignored and not shipped.

The original SoD description follows for historical context, not as a claim of complete support on every modern client.

`Locale.lua` and `Locales/` centralize interface text in enUS, deDE, frFR, esES, ruRU, koKR, zhCN and zhTW. Catalog parity, format arguments and references are checked by `.examiner-tools/localization.cjs`; all eight locales run the client regression suite. Blizzard supplies gameplay names and native labels; technical diagnostics intentionally remain English. Translations and layouts still need native-speaker/in-game acceptance. Missing a mouseover target leaves the existing inspection open.

Forever reads its native nine-value inspect honor response (rank, points, threshold, kills), with rank artwork and supplied arena weekly records. Arena inspection is retained because GetInspectArenaData is listed in the Forever client API export; missing APIs/responses produce no rows. Talents use separate native group tabs and Forever class artwork. Copy build appears only with an actual export string; Forever has a documented foreign-build export API but no configured calculator-link integration. Legacy APIs currently verified in Blizzard UI read the local player's configuration/progress, not arbitrary inspected players; Examiner never substitutes those for foreign Legacy data.

All bundled libraries live under `Libs/`. `Examiner.toc` is the single metadata source: run `node .examiner-tools/manifests.cjs --write` after editing it to regenerate client/working manifests. Tests and builds reject out-of-sync manifests; only interface numbers and temporary working-copy configuration intentionally differ. Client contract tests additionally cover native Classic honor tuples, TBC arena teams, and Mists talents/glyphs/5v5, with unsupported APIs removed or rejected.

Classic/SoD talents use the current Blizzard specialization API and talent-ID tooltips. New complete cache snapshots include all three trees of the viewed talent group; older point-only snapshots cannot reconstruct trees. Classic PvP shows rank/title directly. Mists uses native talent-query results without the incompatible deprecated wrapper; supplied glyphs remain a separate tab. Retail/Forever PvP reads matching inspect responses without requiring the removed honor-request functions, and accepts later honor updates. Client-specific fields are filtered for live data and cached snapshots. Guild counts come from inspection, never the local roster. Partial talent snapshots are retained when no suitable complete snapshot exists; transient PvP omissions can retain values already received in the same capture, without merging across players, clients or PvP captures.

I'm a fan of the original addon (SuperInspect and Examiner). Since it no longer worked, I extensively modified and extended it for all Classic SoD phases 1–8 — adding a new Rune module, fixing the talents and honor tabs, adding gear score stats and more.

---------------------------------------

* Rune page
* Average item level/gear score
* Lots of fixes (talents, honor tabs etc.)

![Screenshots of Addon](https://i.ibb.co/KxdQbSF3/all-in-one.jpg)


Examiner - An Advanced Inspection Addon
---------------------------------------
With Examiner, you can check/inspect other players gear, talents, runes and honor details.

When you inspect someone, it will show the 3D model of the character (or even NPC) and a stat summery of all their equipped gear combined. Please note that these values are from gear alone, and will not include bonuses from buffs, talents or normal base stats.

Each player you inspect can be cached, that way you can look them up later, even when they are not around.
The option to cache others is disabled by default, you will have to enable caching on the "Config" page.

You can bind a key to inspect your target, you can even bind a key to inspect whoever is under your mouse, without having to target anyone (stealth inspection). To set this up, open the Key Bindings dialog and look under "Examiner".

One of the commands: /ex inspect <unit> or /ex i <unit>

Examiner does not use that much memory by itself, but once you start caching a lot of people, memory usage can grow quite quickly.

You can always find the latest release of this addon on Curse or WoWInterface
- https://www.curseforge.com/wow/addons/examiner-classic-sod
- https://www.wowinterface.com/downloads/fileinfo.php?id=26695

Comparing Gear
--------------
To compare one person's gear with another, you can mark a target for compare, by right clicking on the "Stats" button to get the drop down menu to open,
this menu will have an entry called "Mark for Compare". You can also use the shortcut by holding down Shift when clicking the "Stats" button.
When marked for compare, the Stats page will no longer show the actual stats of your inspected person, but will instead show the difference in stats
compared to the person you marked for compare.

Cache Filtering
---------------
If your number of cached entries is getting quite high, you may want a way to filter out specific players.
First you have to open the filter dialog, do this by right clicking on the Cache button and pick "Filter...", or use the shortcut by holding down the Shift key and then click the Cache button.
The filter works a bit similar to the /who function in WoW, so you can for example set the filter to "1-79" and it will show all non level 80s.
To only show a specific class, you can use the filter "class:deathknight", and only Death Knights will be shown.
You can add as many filter matches as you want, so using the filter: "class:hunter race:nightelf guild:awesome" will show all Night Elf hunters from the guild <Awesome>.
Filter matches cannot have spaces, you must write them without, that is why "Death Knight" has to be written as "DeathKnight", you can even just use "deathk" it does not have to match the entire thing.
You can use the filter type "sex" to match males or females. Using "sex:2" will match males, "sex:3" will match females.
There are many filter types, here are some examples: "class", "race", "realm", "guild", "guildRank", "sex" and "zone".

Model Frame Controls
--------------------
Left Click + Move:		Rotates the Model
Right Click + Move:		Moves the Model
Mousewheel:				Zoom
Ctrl + Left Click:		Change Background
Ctrl + Right Click:		Toggle Background
Shift + Left Click:		Reset Model Position 

Slash Commands
--------------
The slash command for Examiner is /examiner or just /ex.

Although you probably wont need to use any slash commands as almost everything is available from the UI,
there are a few things which can only be done through slash commands.

/ex inspect <unit> or /ex i 'unit'
This one will inspect the given unit (target, focus, party3 etc). If no unit token is given, it will inspect target and then player if no target exist.

/ex si <itemLink>
This command will scan just a single item and list its combined stats in the chat frame.
Holding down ALT while the mouse is over an item in Examiner will show a tooltip with the stats like this.

/ex compare <itemLink1> <itemLink2>
Compares two items and lists the stat differences.

/ex arena <rating>
Shows you the amount of arena points the given rating gives for 2v2, 3v3 and 5v5.

/ex rating <stat> <rating> <level>
Converts a given stat rating into the amount it gives in percentage, at the specified level. Will use your level if omitted.

/ex scale <value>
Changes the scale of the Examiner window.

/ex reset
Resets the position in case it was moved off screen.

/ex clearcache
Clears the entire cache of Examiner.

Special Thanks
--------------
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

Lacking Features, Ideas & Problems
----------------------------------
- Always listen for INSPECT_READY, and invalidate the current unit if an event is recieved that is not "our" unit.
- Cache: Modify the function that builds a list of players from the filter, to take a table parameter, so external code can request a filterd list, without modifying the cache list.
- Module's OnInitialize() shouldn't run until first time Examiner is opened. This would allow for much more optimization.
- mod:HasData() should be posting an event. It messes with the modlist module.
- Locked frames seem to have moved a bit up as of 4.0, change this in Examiner to so it will align with other frames.
- Bring back the ability, as a new module, to send an inspected player to another person with Examiner.
