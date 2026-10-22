# Bundled library snapshot

- Library: LibFroznFunctions-1.0, minor **71**.
- Source: locally installed `TipTacTalents/libs/LibFroznFunctions-1.0`, TipTacTalents version `10.19.26`, copied on 2026-10-20.
- Core SHA-256: `493F5059CDEE96E5B272649D64EDFFF5FC90A29008D662358A185276AAFF8777`.
- Core, LibStub, XML and every referenced data table are copied together, without Examiner-specific edits. Examiner has no runtime dependency on TipTac.
- The library's embedded LibStub is the only bundled/loaded copy in Examiner. Other bundled modules share that global instance; the former duplicate at Libs/LibStub has been removed. The vendor manifest remains unchanged and loads LibStub before the library core.
- Upstream project: https://github.com/frozn/TipTac . Copyright/author notices in the source files are retained. The upstream GPL-3.0 license text is included as `LICENSE`.

This is deliberately described as a **local snapshot**, not an unmodified current upstream release: the installed version includes Forever changes. The upstream library at checked commit `d6422937fdfd9b16036602fb97dd92fad97ac561` has minor 67. Its license was retrieved from that repository. Upstream and local version numbers must not be treated as proof that their contents are identical.

`.examiner-tools/Sync-Library.ps1` in the project root can repeat the local vendor synchronization. Review source/version before running it against a newer installation. Six unreferenced CataC/TWW lookup tables were removed on 2026-10-21; no file referenced by the vendor manifest was removed or changed. A new synchronization can restore those unused upstream tables.

The old Examiner-only `GetQualityFromGearScore` helper is not assumed to exist. Examiner consumes the quality color returned alongside `TacoTipGearScore` by `GetAverageItemLevel`. Updating this library alone does not validate every item-level/stat calculation.
