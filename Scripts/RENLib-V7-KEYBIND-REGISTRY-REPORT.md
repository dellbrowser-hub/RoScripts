# RenLib V7 Managed Keybind Compatibility Report

Migration date: 2026-06-22

## Result

Eight RenLib scripts now register every script-level keyboard shortcut as a non-visual managed keybind. The Keybind Manager can display, edit, reset, save, and autoload these shortcuts. Runtime input handlers read each controller through `:Get()` instead of comparing against a hardcoded feature key.

- 20 script shortcuts registered
- 8 scripts changed
- 0 new visible key-picker controls added
- 0 remaining hardcoded feature-key comparisons in the changed scripts
- 0 legacy `CurrentValue`, `CurrentOption`, `CurrentKeybind`, or `CurrentKey` reads in the changed scripts
- 8/8 changed scripts passed syntax parsing after Luau-only syntax normalization
- No repository push performed

The API audit used the latest GitHub `main` commit available during the migration: `492111ff2902ff26eb3119a0b112c46338829385` (`Update RenLib.lua`, 2026-06-22).

## Changed files and registered shortcuts

### CarSPM

Registered five hold shortcuts:

- Speed Up — `CarSPM_SpeedUpKey`
- Speed Down — `CarSPM_SpeedDownKey`
- Brake — `CarSPM_BrakeKey`
- Instant Brake — `CarSPM_InstantBrakeKey`
- Unreal — `CarSPM_UnrealKey`

The existing custom keybind page was retained to preserve behavior. Both that page and RenLib's manager now edit the same controllers. Controller changes are synchronized back to the script's existing keybind table and custom config file.

### Criminality.lua

Registered two press shortcuts:

- Aimbot Toggle (Primary) — `CriminalityAimbotPrimaryKey`
- Aimbot Toggle (Secondary) — `CriminalityAimbotSecondaryKey`

The original LeftAlt and RightAlt behavior remains available as two independently editable shortcuts.

### HollowPoint.lua

Registered two press shortcuts:

- Aimbot Toggle — `HollowPointAimbotKey`
- Night Vision Toggle — `HollowPointNightVisionKey`

Removed HollowPoint's duplicate private rebinding dispatcher and its two in-tab rebind buttons. The native Keybind Manager is now the sole owner of those bindings.

### Masacre.lua

Registered five shortcuts:

- Aimbot Toggle — `MasacreAimbotKey`
- Target Everyone Toggle — `MasacreTargetModeKey`
- Light Helmet Toggle — `MasacreLightHelmetKey`
- Noclip Toggle — `MasacreNoclipKey`
- Sprint — `MasacreSprintKey`

Sprint remains hold-based; the other four remain press toggles.

### OperationOne.lua

Registered Aimbot Toggle as `ArenaAimbotToggleKey`. The forced `Celestial` theme application was removed so RenLib's saved theme autoload remains authoritative.

### Quickdraw-V1.lua

Registered three press shortcuts:

- Aimbot Toggle — `QuickdrawAimbotKey`
- ESP Toggle — `QuickdrawESPKey`
- Crosshair Toggle — `QuickdrawCrosshairKey`

The former private hardcoded key table was removed; feature bodies were retained.

### RenU-V4.lua

Registered Auto-lock Toggle as `AutoLockKey`. The shortcut still persistently toggles auto-lock on/off; it does not temporarily disable it for three seconds. Recent native input `:Get()` fixes, reduced Settings content, and theme-autoload behavior were retained.

### Weaponary.lua

Registered Aimbot Toggle as `WeaponaryAimbotKey`. Status text, notifications, debug output, and the informational Hotkey section now read the controller's current value instead of displaying a stale `X`.

## RenLib API compatibility

The audited `RenLib.lua`, `RenLibBêta.lua`, and `RenLibTesting.lua` builds expose the virtual keybind registry internally, but none currently defines the public `Library:RegisterKeybind(...)` method used by these scripts.

Each changed script therefore includes the same guarded compatibility method:

- It only installs when RenLib does not already provide `RegisterKeybind`.
- It creates `Virtual = true` entries, so no control is inserted into a script tab.
- Controllers expose `:Get()`, `:GetKey()`, and `:Set()`.
- Flags are registered through RenLib's option/config path.
- Defaults are added to `KeybindDefaults` for manager reset support.
- Existing saved values in `Flags` and `PendingAutoloadFlags` are honored.

The fallback can be removed from scripts after an equivalent public method ships in the main RenLib build.

## Risk inventory

| Pattern | Files | Assessment |
| --- | --- | --- |
| Public `RegisterKeybind` absent from current RenLib main | All eight changed scripts | Mitigated with a guarded virtual-registration fallback that defers to an official method whenever one exists. |
| Native manager exposes no public "currently capturing" flag | All eight changed scripts | Added a guarded `IsCapturingKeybind()` check so selecting a new key in the manager does not also activate a script feature. It recognizes both ellipsis and three-dot capture labels. |
| Duplicate key assignments are allowed | All managed keybinds | If a user assigns one key to multiple actions, every matching action may run. This is existing manager behavior; no automatic conflict resolution was introduced. |
| Dual persistence paths | `CarSPM` | Its historical custom config and RenLib config both store keys. `OnChanged` keeps them synchronized, but manual file edits can still create last-loader-wins behavior. |
| Runtime HTTP/loadstring and executor APIs | All changed scripts | Existing dependency retained. No loader or working game module was removed. |
| Drawing/game-specific object assumptions | Gameplay-heavy scripts | Existing logic intentionally retained to avoid unrelated behavior changes. |
| Manual non-RenLib UI toggle | `Skyven.lua` | Skyven still owns a hardcoded RightShift UI shortcut because it does not load RenLib or have a RenLib Keybind Manager. Retrofitting that UI was outside this keybind-registry migration. |
| Movement-state polling | `RenU-V4.lua`, `ParkourRecorder.lua`, `Skyven.lua`, `VideoRecorder.lua` | W/A/S/D, jump, sprint, mouse-look, and recorder state polling are input mechanics rather than editable feature shortcuts; they were intentionally not registered. |
| Roblox runtime validation | All changed scripts | Static parsing and structural scans passed. Final input/UI behavior still requires execution in Roblox because this environment cannot emulate executor APIs, Drawing, or game object hierarchies. |

## Files inspected but not changed

- `VideoRecorder.lua`: its four feature shortcuts already use native `CreateKeyPicker(...)` controllers and are already visible to the manager.
- `ParkourRecorder.lua`: detected keys are recorded movement state, not feature shortcuts.
- `Skyven.lua`: manual UI without RenLib; documented above.
- `BrainrotSniper.lua` and `UIDumperAlpha.lua`: no applicable RenLib-managed feature shortcuts found.

No Obsidian vault files, ignored files, loaders, working modules, or repository history were touched.
