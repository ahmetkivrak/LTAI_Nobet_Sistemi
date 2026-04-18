# LTAI Duty Scheduler - Progress Update

## Version History & Changelog

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
