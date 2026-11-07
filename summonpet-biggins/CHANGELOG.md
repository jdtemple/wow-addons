# SummonPet Biggins v1.2.4

### Fixed
- **Skyriding Dynamic Flight Detection:** Added dynamic flight detection via C_PlayerInfo.GetGlidingInfo(), ensuring the 2.0-second touchdown debounce applies to Skyriding mounts as well as steady flight mounts.
- **Dismount Stealth Race Condition:** Tracked and debounced the dismount summon timer (dismountTimer) to 1.0s and integrated it with UPDATE_STEALTH, guaranteeing that landing, dismounting, and entering stealth simultaneously immediately cancels pending companion summons before stealth can be broken.

### Changed
- **Architectural Flattening:** Refactored runtime logic to use inverted guard clauses and early exits, decomposed mount and dismount handling into dedicated subroutines, consolidated pre-conditions into CanSummon(), and replaced the monolithic 100-line event ladder with an O(1) table dispatcher.
