# LTAI Duty Scheduler - Progress Update

## Version History & Changelog

### v2.3 Code Review & Cleanup (April 19, 2026)
*   **Bug Fix — Archive Statistics Aggregator**: Fixed a critical bug where auto-noted names like `"BE (14:00)"` were not recognized in the statistics window. Applied `_yalnIsim()` to strip auto-notes before matching, ensuring partial-shift workers are counted correctly in DEL/TWR/GND/SUP tallies.
*   **Dead Code Removal**: Removed unreachable `isAraSlotu` flag and `if (isAraSlotu)` block from Phase 2 (daytime engine only — night engine has its own `isAra` logic). Removed unused `isYarin`, `yarinT24`, and `yarinStr` variables that were always false/unused in the daytime-only context.
*   **Redundant Call Cleanup**: Removed duplicate `_hafizayiSifirla()` invocation in `_gruplariGuncelle()` — the call inside `_arsiveOtomatikKaydet()` is sufficient.
*   **Pin UI Declutter**: Removed SnackBar warning popups from manual pin dialog (green/red visual indicators retained for informational purposes).
*   **Deprecated API Migration**: Updated `MaterialStateProperty` → `WidgetStateProperty` and `dataRowHeight` → `dataRowMinHeight`/`dataRowMaxHeight` across all DataTable instances (Flutter 3.19+ compliance).
*   **Misc Cleanup**: Removed dead comments, extra blank lines, added HOTO TODO placeholder, added session-only documentation for time editing behavior.

---
### v2.2 State Isolation Update (April 19, 2026)
*   **Separation of Concerns (Day vs. Night)**: Split the previously global manual preference states (`gunlukDurum`, `ilkSecilenler`, `ortaSecilenler`, `sonSecilenler`, `bizimleKalSecilenler`, `supOnlySecilenler`) into independent `Gunduz` and `Gece` trackers.
*   **Prevented Cascade Conflicts**: Handled a critical issue where applying restrictive tags (like `SUP ONLY` or `BİZİMLE KAL`) in the Day schedule silently persisted in the Night schedule, creating artificially empty seating slots because the restricted constraints could not be mapped to the newly computed sector limits.
*   **State Transparency**: Actions in one UI context are now isolated from the other using `isGunduzVardiyasi` proxy getters/setters, ensuring that each generated schedule has untampered access to its specific pool configuration.

---

### v2.1 Stability Update (April 18, 2026)
*   **Edge Case Protection**: Added division-by-zero safeguards when `anlikTrafik` is empty on initialization.
*   **Null Safety (SharedPreferences)**: Enforced `try-catch` structures around JSON operations for `Personel` and `NotamPrefs` loading to prevent application crashes on launch with corrupt data.
*   **Night Mode Polish**: Automatically purged unneeded "Karınca" (Ant) and "Ağustos Böceği" (Cicada) interactions from the nightly wrap-around engine interface to maintain clean chronological cycles. Removed redundant rendering parameters (`isPinned`, `isConflict`, `isVizesiz`) from `main.dart`.
*   **UI Tweaks**: Condensed large button texts to prevent horizontal overflow in dynamic layouts. Correctly restricted algorithmic requirement calculators to ignore AI numbers when a manual override is selected.

---

### v2.0 Gece Motoru Güncellemesi
We finalized the deterministic zigzag duty scheduling algorithm. The core engine has been updated to ensure equitable shift distribution and correct role assignments based on a numbered cycle template.

*   **Zigzag Number Template**: Implemented a round-robin numbering scheme to dynamically map slots.
*   **Role Mapping**:
    *   **KARINCA (Hard workers)**: Automatically mapped to numbers with the most shifts. Also factors in specific slot preferences (early vs. late).
    *   **AĞUSTOS BÖCEĞİ (Light workers)**: Automatically mapped to numbers with the fewest shifts.
*   **SUP Management**: Improved the allocation logic for SUP members to guarantee they are distributed to different slots without overlapping unless necessary. Introduced SUP Rotation (Joker SUP): Actual SUP-authorized personnel are given resting rounds if they already served as SUP today; a random available non-SUP logic picks up Joker SUP shifts to ensure roster fairness.
*   **BK Prioritization**: "Bizimle Kal" (BK) personnel are now properly maintained in the active roster but excluded from the final slot assignment.
*   **UI Consistency**: Added explicit indicators in the shift requirement overlay to accurately reflect manual selection overrides `(Seçili: X K Y A)`.

## Next Steps
- Verify automated testing for the new slot distribution scheme.
- Perform sanity checks on edge cases (e.g., highly asymmetric active roster).
- Final UI polish for personnel tracking.
