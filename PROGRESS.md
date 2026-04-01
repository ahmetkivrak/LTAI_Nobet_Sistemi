# LTAI Duty Scheduler - Progress Update

## Current Status
We are currently finalizing the deterministic zigzag duty scheduling algorithm. The core engine has been updated to ensure equitable shift distribution and correct role assignments based on a numbered cycle template.

## Recent Updates
*   **Zigzag Number Template**: Implemented a round-robin numbering scheme to dynamically map slots.
*   **Role Mapping**:
    *   **KARINCA (Hard workers)**: Automatically mapped to numbers with the most shifts. Also factors in specific slot preferences (early vs. late).
    *   **AĞUSTOS BÖCEĞİ (Light workers)**: Automatically mapped to numbers with the fewest shifts.
*   **SUP Management**: Improved the allocation logic for SUP members to guarantee they are distributed to different slots without overlapping unless necessary.
*   **BK Prioritization**: "Bizimle Kal" (BK) personnel are now properly maintained in the active roster but excluded from the final slot assignment.
*   **UI Consistency**: Added explicit indicators in the shift requirement overlay to accurately reflect manual selection overrides `(Seçili: X K Y A)`.

## Next Steps
- Verify automated testing for the new slot distribution scheme.
- Perform sanity checks on edge cases (e.g., highly asymmetric active roster).
- Final UI polish for personnel tracking.
