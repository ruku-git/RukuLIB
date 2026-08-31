# MASTER — iOS Roblox UI Lib

Design system source of truth for the library. Every value in `library.lua` traces back to a token defined here — no magic numbers in the implementation.

Provenance: glassmorphism effect spec and the `Minimal Swiss` (Inter) typography pairing below are pulled verbatim from the `ui-ux-pro-max` skill dataset (`styles.csv` / `typography.csv`, verified against the query). The `--design-system` full-aggregate command returned an FAQ/documentation landing pattern with a generic dev-tool navy palette — off-target for a floating iOS-style utility sheet — so the color table below is hand-specified directly from Apple's documented HIG dark-mode system tones instead of that result, per the skill's own guidance to fall back to clearly-labeled general guidance when the aggregate match is off-topic.

## 1. Style

**Glassmorphism (Dark Mode)** — verified spec:
- Backdrop blur: 10–20px (we use 20px on the outer sheet)
- Translucent surface: `rgba(255,255,255,0.10–0.15)` over the dark base
- Border: 1px solid `rgba(255,255,255,0.10–0.20)`
- Elevation via blur + soft outer shadow, not flat drop-shadow
- Anti-patterns to avoid (AI-slop guard): no giant/loud buttons, no neon rainbow gradients, no drop-shadow-only "flat glass," no mixing filled+outline icons at the same hierarchy level, no emoji-as-icon

## 2. Color — Apple HIG Dark System Tones

| Token | Hex | Usage |
|---|---|---|
| `bg.base` | `#0B0B0C` | app/window backdrop behind the sheet |
| `bg.frame` | `#1C1C1E` | primary sheet surface (systemBackground, dark) |
| `bg.dock` | `#141416` | left nav dock (secondarySystemBackground) |
| `bg.card` | `#232325` | icon slots / row surfaces (tertiarySystemBackground) |
| `bg.editor` | `#0B0B0C` | code viewport well |
| `border.hairline` | `rgba(255,255,255,0.10)` | glass edge / separator |
| `border.subtle` | `#3A3A3C` | opaque borders (separator, dark) |
| `text.primary` | `#F5F5F7` | titles, primary labels |
| `text.secondary` | `#8E8E93` | secondary labels (systemGray) |
| `text.tertiary` | `#636366` | captions, version tags |
| `accent.blue` | `#0A84FF` | selection, primary action (systemBlue, dark) |
| `accent.green` | `#34C759` | toggle-on, success (systemGreen, dark) |
| `accent.red` | `#FF453A` | destructive, danger (systemRed, dark) |
| `accent.orange` | `#FF9F0A` | warning / guide markers |

### Luau constants

```lua
local Colors = {
	BgBase     = Color3.fromRGB(11, 11, 12),
	BgFrame    = Color3.fromRGB(28, 28, 30),
	BgDock     = Color3.fromRGB(20, 20, 22),
	BgCard     = Color3.fromRGB(35, 35, 37),
	BgEditor   = Color3.fromRGB(11, 11, 12),
	BorderSubtle  = Color3.fromRGB(58, 58, 60),
	TextPrimary   = Color3.fromRGB(245, 245, 247),
	TextSecondary = Color3.fromRGB(142, 142, 147),
	TextTertiary  = Color3.fromRGB(99, 99, 102),
	AccentBlue    = Color3.fromRGB(10, 132, 255),
	AccentGreen   = Color3.fromRGB(52, 199, 89),
	AccentRed     = Color3.fromRGB(255, 69, 58),
	AccentOrange  = Color3.fromRGB(255, 159, 10),
}
```

Glass hairline border (`rgba(255,255,255,0.10)`) is implemented as `UIStroke` with `Color = Color3.new(1,1,1)`, `Transparency = 0.9`.

## 3. Typography

Verified pairing: **Minimal Swiss** (Inter, single-family, weight-driven hierarchy) — closest web-verified analog to San Francisco's "one family, many weights" philosophy, used for the HTML preview.

Roblox-native mapping (no custom font upload needed → zero fingerprint):

| Role | Font | Weight | Size |
|---|---|---|---|
| Title | `Enum.Font.GothamMedium` (fallback: `Enum.Font.SourceSansSemibold`) | Medium | 16px |
| Subtitle / caption | `Enum.Font.Gotham` | Regular | 11px |
| Body / row label | `Enum.Font.GothamMedium` | Medium | 13px |
| Row description | `Enum.Font.Gotham` | Regular | 10px |
| Code | `Enum.Font.Code` | Regular | 11px |

If a custom family is ever wanted: `Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)` — kept optional since asset-free is the default (matches Phase 4's zero-fingerprint requirement).

## 4. Radius, Spacing, Stroke

| Token | Value |
|---|---|
| `radius.sheet` | 20px |
| `radius.card` | 14px (standard) |
| `radius.slot` | 10px |
| `radius.pill` | 999px (fully rounded — toggles, thumbs) |
| `stroke.hairline` | 1px |
| `padding.sheet` | 16px vertical / 22px horizontal |
| `padding.editor` | 12px |
| `gap.row` | 8–10px |
| `gap.dock-icons` | 40px (32px icon + 8–40px rhythm, center-aligned in 64px dock) |
| `dock.width` | 64px |
| `window.size` | 550 × 350 |

Spacing follows a 2/4/8/12/16/22px rhythm — every value above is a multiple of 2, no arbitrary in-between numbers.

## 5. Motion

| Interaction | Duration | Easing |
|---|---|---|
| Window open/close | 220ms | `Enum.EasingStyle.Quad`, `Enum.EasingDirection.Out` |
| Tab switch (crossfade) | 160ms | `Enum.EasingStyle.Quad`, `Out` |
| Toggle thumb slide | 220ms | `Enum.EasingStyle.Quad`, `InOut` |
| Hover / press (scale, bg) | 140–160ms | `Enum.EasingStyle.Quad`, `Out` |
| Nav-slot select | 160ms | `Enum.EasingStyle.Quad`, `Out` |
| Dropdown flyout open/close (height + fade) | 160ms | `Enum.EasingStyle.Quad`, `Out` |
| Dropdown option select (highlight tint) | 160ms | `Enum.EasingStyle.Quad`, `Out` |

One shared duration/easing family across the whole library (per `motion-consistency` guidance) — everything is Quad, nothing mixes spring/linear/back into the same interaction language.

## 6. Icons

SVG-equivalent vector icons only (Roblox: `ImageLabel` with `rbxassetid` icon pack, or hand-built `Frame`+`UICorner` glyphs for zero-asset mode — the library defaults to the latter). No emoji. One stroke weight (1.3–1.6px equivalent) across the icon set. 32×32 tap target on the dock, exceeding the 44×44pt Apple minimum is not required here since this is desktop-style pointer UI, not touch — kept at 32px visual with the full 64×~54px dock cell as the effective hit area.

**Built-in vector glyphs** (`library.lua`, `IconBuilders`, 16×16 canvas, zero rbxassetid dependency):

| Key | Reads as | Built from |
|---|---|---|
| `"terminal"` | Executor | rounded outline "screen" (`UIStroke`) + short cursor bar |
| `"stack"` | Script Hub | 3 stacked horizontal bars, equal length |
| `"sliders"` | Settings | 3 horizontal tracks (static `border.subtle`) + offset knob circles |
| `"dot"` (default) | generic / unspecified | single centered circle, used when `Icon` is omitted |
| `<number>` | custom | falls back to real `rbxassetid://` image for teams that want to swap in a real icon pack later |

Active-tab tint: every glyph part (except a track named `IconTrack`) retints from `text.secondary` → `text.primary` on selection, same `Motion.Tab` timing as the slot background — see `tintIcon()`.

## 7. Dock Toggle

A round 24px button, floating at a fixed `(12, 10)` offset on the sheet itself (not inside the dock, so it survives the dock collapsing to 0 width). Glyph: a small "sidebar" outline with an off-center vertical divider — the universal collapse-sidebar affordance. Click collapses/expands the dock (`Spacing.DockWidth` ↔ `0`) and the content pane resizes to fill; `content`'s left padding grows from `22px` to `46px` while collapsed so title text always clears the floating button. Same `Motion.Tab` (160ms Quad) as everything else — no separate motion language introduced for this control.

The dock's own `UICorner` (`radius.sheet`, 20px) is tweened down to `0` in lockstep with the width tween on collapse (and back up on expand) — a fixed 20px radius on a frame narrower than 40px renders as a rounded blob for the last stretch of the animation otherwise. Only the dock's *left* two corners are ever meaningfully rounded in practice: the right two (an internal seam against `content`, never near the sheet's own silhouette) are squared back off by a same-`bg.dock`-color flush patch (`RightSquareOff`) sized `radius.sheet` px wide, so the dock reads as one continuous frame with the sheet rather than an independently-rounded panel bolted onto it.

## 8. Window Drag

The `Header` frame (title + subtitle, top of the content pane) is draggable — `Active = true` plus the same `UserInputService`-global drag idiom the slider uses (`InputBegan` captures start position, global `InputEnded` clears the flag, global `InputChanged` accumulates pixel delta into `Sheet.Position`'s `Offset` components, `Scale` untouched). No separate "grab handle" — the whole header row is the drag target, standard for a floating utility sheet at this scale.

## 9. Toast Notifications

`Library:Notify({Title=, Text=, Duration=4})` — independent of any `Window` (own top-level `ScreenGui`, `DisplayOrder = 1000`, above the main window's `999`), so it works before `CreateWindow` or to surface something outside the window's own lifecycle. Toasts stack bottom-right (`AnchorPoint (1,1)`, `16px` inset), an `AutomaticSize.Y` stack frame that grows *upward* as toasts accumulate (oldest toast ends up at the top, newest nearest the corner). Toast card: `bg.card`, `radius.card`, hairline stroke, fades in (`Motion.Open`) and — after `Duration` seconds — fades every text/stroke element to fully transparent (`Motion.Tab`) before destroying itself.

## 10. Theme Support

`Colors` is one shared table every widget reads from at creation. `Library:SetTheme("Dark" | "Light" | {custom palette})` mutates that table in place, then re-runs a registry of small closures (`onTheme`/`themed()`, see `library.lua`) that each know how to re-apply one already-built instance's color from the current `Colors` table — so an already-open window re-themes live, no window recreation needed. Two built-in palettes: `Library.Themes.Dark` (a snapshot of §2's table, taken at load time) and `Library.Themes.Light` (Apple HIG *light*-mode system tones — `#F2F2F7` base, `#FFFFFF` frame/card, dark-on-light text, same accent hues). A raw `{BgFrame = Color3...}` table works too for a fully custom developer palette; unspecified keys keep their current value (merge, not replace).

Coverage is broad but pragmatic, not exhaustive: static idle colors (row backgrounds, labels, the sheet/dock/header chrome, idle control faces) are registered and re-theme correctly; anything that already re-reads `Colors` fresh at interaction-time (a toggle's on/off track color, a dropdown option's highlight) picks up the new palette on its next interaction for free, or is explicitly re-run via `onTheme` where idle correctness matters (e.g. dropdown `highlight()`). A color picker's own hue/saturation gradients are intentionally never theme-driven — they're HSV math, not palette lookups.

## 11. Configuration Saving

Any widget that returns a `{Set, Get}` control (`Toggle`, `Slider`, `Dropdown`, `MultiDropdown`, `Input`, `Keybind`, `ColorPicker`) accepts an optional `Flag = "SomeName"` in its config; if present, the control registers itself in `Library.Flags[Flag]`. `Library:SaveConfig(name?)` walks every registered flag, calls `:Get()`, JSON-encodes the result (`Color3` wrapped as `{__color3=true, R=,G=,B=}` since it isn't a native JSON type) via `HttpService:JSONEncode`, and writes it with the executor's `writefile` to `Library.ConfigFolder/<name>.json` (default folder `IOSRobloxUILib_Configs`, default name `"default"`). `Library:LoadConfig(name?)` reads it back with `readfile`, `JSONDecode`s it, and calls `:Set()` on every flag with a live control — each widget's `Set` fires its own `Callback`, so loading a config actually re-applies the effect (re-enables Fly Hack, re-picks the dropdown mode), not just the visual state. Missing file, decode failure, or an individual `Set` erroring (e.g. a stale slider value outside a since-changed `Range`) all fail soft — logged as a return value, never a thrown error.

Configs are named (not one fixed file) specifically so a script can offer multiple saved presets. `sanitizeConfigName` strips anything not filename-safe (falls back to `"config"` on an empty/all-stripped name) before either function touches the filesystem. `Library:ListConfigs()` returns every saved name (extension stripped, alphabetically sorted) by `listfiles`-ing the config folder — feeds `CreateConfigManager`'s load flyout. `Library:DeleteConfig(name)` removes one file via `delfile`. All three new calls fail soft the same way (return `{}`/`false` rather than throwing) if the executor lacks `listfiles`/`makefolder`/`delfile`.

A keybind that opens/closes the whole menu (§13) is just an ordinary `CreateKeybind` with a `Flag` — no special-cased "menu keybind" concept exists. Because it's Flag'd like any other control, the chosen bind itself round-trips through `SaveConfig`/`LoadConfig` for free.

## 12. New Widgets

| Widget | Shape | Notes |
|---|---|---|
| **Input** (`CreateInput`) | `radius.slot` `TextBox`, 120×26, right-aligned like Dropdown | `NumbersOnly` strips non-numeric chars on commit; commits on `FocusLost` |
| **Keybind** (`CreateKeybind`) | `radius.slot` button, 88×26, shows the bound key name or "None" | Click to listen for the next key press (text → `AccentBlue` "..." while listening); `Escape` cancels without rebinding; a global `InputBegan` listener fires `Callback` whenever the bound key is pressed elsewhere |
| **Multi-Select Dropdown** (`CreateMultiDropdown`) | Same Overlay-parented flyout as Dropdown, 140px wide, each option gets a 14px checkbox | Button label shows a comma-joined list of selections, or "None" |
| **Color Picker** (`CreateColorPicker`) | 40×26 swatch button opens a 180×190 Overlay-parented panel: SV square + hue strip + hex `TextBox` | SV gradient is two overlaid frames using `UIGradient.Transparency` sequences (white→transparent horizontal for saturation, transparent→black vertical for value) over a pure-hue background — zero-asset, no image needed. Hue strip is a 7-stop rainbow `ColorSequence`. Hex box accepts `#RRGGBB` or `RRGGBB`, invalid input snaps back to the last valid color on `FocusLost` |
| **Config Manager** (`CreateConfigManager`) | Two 50/50-split rows (not the usual label+control shape): Row 1 `[Save Config][name box]`, Row 2 `[Load Config][selection box]`. The selection box opens a 150px-wide Overlay-parented flyout | Doesn't register a `Flag` — action panel, not a value-holding widget. Picking a name from the flyout only loads it *into the selection box* (`selectLabel.Text`) — it does **not** call `Library:LoadConfig` — pressing the separate `Load Config` button on the same row is the deliberate commit step, so browsing saved configs can't accidentally reset live widget state on a stray tap. Saving clears the name box immediately after (`nameBox.Text = ""`), ready for the next name. Each flyout row is `<config name>` + a small `×` delete glyph (`AccentRed`); deleting the config currently sitting in the selection box resets it to `"None"` rather than leaving `Load Config` pointing at a file that no longer exists. `config.Callback` fires as `(action, name, ok, err)` for `"save"`/`"load"` (a `"load"` with nothing selected fires `ok=false, err="no config selected"`) so a host script can toast the result. Unlike Dropdown/MultiDropdown/ColorPicker, its option rows are rebuilt fresh on every open (`rebuildRows()`) rather than fixed at widget-creation time, since the saved-config set can change between opens. Meant to sit inside a `CreateSection` (§15) card, e.g. alongside a `Theme` section — see `demo.lua`'s Settings tab |

All four flyout-style widgets (Dropdown, MultiDropdown, ColorPicker, Config Manager) follow four hard-learned rules from `SESSION_NOTES.md` bugs #6–#15:
1. Parent the flyout to `Window.Overlay` (never nest it inside its own row — same branch as sibling rows lets a single click register on two buttons at once).
2. Give every clickable option inside it an **explicit** `ZIndex` matching the flyout's own (ZIndex is never inherited from parent in Roblox — an unset option button defaults to `1` and ties with whatever row-content sits behind the flyout).
3. Position it with the shared `positionFlyout(sheet, anchorBtn, flyout, flyoutHeight, gap?)` helper (`library.lua`, defined right after `labelBlock`), never a bespoke below-the-button-only calculation — `sheet.ClipsDescendants = true` silently clips a flyout that overflows past the sheet's bottom edge (bug #13: the color picker's hue bar + hex box got cut off entirely). The helper tries below first, flips above if there's no room, and clamps as a last resort. Config Manager also re-runs this on every content change (open, and after a delete), since its content height isn't fixed like the other three.
4. On open, call `self.Window.CloseActiveFlyout()` first, then re-point `self.Window.CloseActiveFlyout` to a closure that closes *this* flyout. `CreateTab`'s `activate()` calls it unconditionally on every tab switch — flyouts live in `Overlay`, a Window-level layer outside any Tab's own `Page`, so nothing about switching tabs naturally closes them otherwise (bug #14: an open color picker stayed visible after switching away from its tab). This also means only one flyout can ever be open at a time. Same ordering (call it BEFORE flipping the local `open` flag) also matters for the self-reentrancy fix from bug #15 — see `SESSION_NOTES.md`.

Any future flyout-shaped widget should follow all four from the start rather than rediscovering them. A widget whose content can change between opens (Config Manager being the first example) additionally needs its rebuild-and-resize step run on *every* mutation while open, not just at open-time — a bug caught live in this same session: a `×` delete handler that calls the rebuild function but discards its returned height leaves the flyout's `Size` stale against its new row count.

## 13. Floating Menu Toggle Button + Menu Visibility

`Window:SetVisible(bool)` / `Window:ToggleVisible()` show or hide the whole `Sheet` (fade via `Motion.Open`/`Motion.Tab`, matching the window's own open-animation transparency of `0.04`), independent of the dock-collapse toggle (§7, which only collapses the side dock while keeping the window itself shown). Also calls `self.CloseActiveFlyout()` on every visibility change so hiding the menu never leaves a flyout stranded behind a hidden sheet.

A round-cornered `FloatButton` (48×48, `bg.card`, a hand-built 3-bar zero-asset "menu" glyph) is a sibling of `Sheet` on the same `ScreenGui` — not a child of it — specifically so it stays visible and tappable while the menu itself is hidden; that's the entire point of a floating toggle. `ZIndex = 500`, above everything used inside `Sheet` (dock-toggle glyphs top out at 27, flyouts at 10/11). Default position `(1,-24),(1,-24)` (bottom-right, anchored `(1,1)`).

Draggable with the exact offset-accumulation idiom as the header drag (§8) — captures `Position` on `InputBegan`, accumulates pointer delta into the `Offset` components on global `InputChanged`, clears on global `InputEnded`. Distinguishes a drag from a tap by total pointer travel: below a `6px` threshold on release, it's treated as a tap (fires the toggle) rather than a drag. No screen-bounds clamping — consistent with the header/window drag, which also doesn't clamp.

A keybind that calls `Window:ToggleVisible()` from its `Callback` is just an ordinary `CreateKeybind` widget (see §11) — the library has no separate "menu keybind" API surface. `demo.lua`'s Settings tab wires one up (`CurrentKeybind = "RightControl"`, `Flag = "MenuToggleBind"`) as the reference pattern.

## 14. Icon Pack Evaluation (Aug 28, 2026)

Considered swapping the hand-built `IconBuilders` (§6) for [`latte-soft/lucide-roblox`](https://github.com/latte-soft/lucide-roblox). Rejected: it delivers icons as `rbxassetid://` images (an external dependency this library is explicitly built to avoid — see file header, "no models, no asset dependencies"), which for a `loadstring`'d executor script means depending on specific asset IDs staying live and un-moderated indefinitely; the repo was also archived (read-only) on Jul 21, 2026, so a broken/pulled asset ID would have no upstream fix. The current zero-asset vector glyphs have none of that failure surface. Revisit only if a specific icon is genuinely too complex to hand-build as `Frame`+`UICorner` primitives.

## 15. Grouped Sections (`CreateSection`)

Groups related widgets under one titled card — e.g. the Settings tab's `Theme` and `Config` cards — instead of them sitting as loose rows in the tab, matching the grouped-table-view convention (iOS Settings.app) the whole visual language is already leaning on. `Tab:CreateSection({Title = "..."})` returns a **Section** object carrying the exact same `TabMeta` metatable as a real Tab: every existing `CreateXxx` widget constructor (including flyout-having ones — `Window` is threaded through unchanged, so Overlay-parenting and `positionFlyout` keep working correctly) works on it completely unmodified. The only thing that differs is where `Page` and `RowCount` point — at the section's own inner `Body` frame and its own counter, instead of the tab's.

Visual shape: an outer card (`bg.frame`, `radius.card`, hairline stroke, `AutomaticSize.Y`) containing a small `text.secondary` header label, then a `Body` frame (also `AutomaticSize.Y`) holding whatever rows get created on the Section. Rows created inside a Section get `FlatRows = true` set on the Section object, which tells `baseRow` to skip each row's own `bg.card` tint (`library.lua`) — without this, a normal row's own card background stacked on top of the section's card background reads as a slightly muddy card-on-card double-tint instead of one clean grouped card.

## 16. Bug Batch Fixes (Aug 29/30, 2026)

An external code review (ChatGPT, run against the source with MCP down — no live client to test against) surfaced 13 findings; 11 held up under code-level verification and got fixed here, 1 was genuinely minor, 1 was overstated (see `SESSION_NOTES.md` for the full per-item verdict). All 11 fixes were re-verified live once the client reconnected.

**Missing `Callback` on `Set` (MultiDropdown, ColorPicker)**: both widgets' `Set` updated their own visuals/state but never called `task.spawn(callback, ...)` — the exact class of bug already caught and fixed for `Toggle` earlier in this project (see the Aug 28 session). `LoadConfig` restoring either one would show the right UI state (checkboxes, swatch) without ever re-applying the actual effect. Both now fire their callback with the same value shape their own `Get` returns.

**Global `UserInputService` connection leak**: every `UserInputService.Input*:Connect` in the file (9 call sites — window drag, floating-button drag, slider drag, keybind listener, color picker drag) is service-level, so destroying the widget/window that created one never disconnects it on its own. Re-running `CreateWindow` — this project's own normal dev loop — used to stack a full new set on every run with nothing ever removed. Fixed via a `trackConnection`/`clearGlobalConnections` pair (`library.lua`, right after `themed`): every one of those 9 connect calls now routes through `trackConnection`, and `CreateWindow` calls `clearGlobalConnections()` before building anything new, alongside resetting `ThemeListeners` and `self.Flags` (see below) — all three are the same shape of problem: state that outlives the `:Destroy()` call because it was never tied to an Instance in the first place. Verified live by measuring `#getconnections(UserInputService.InputBegan)` (the one signal only `CreateKeybind` ever touches) across two `CreateWindow` generations — delta was exactly `-1` (old generation's connections removed, then one new one added), which is only possible if the leak is actually fixed; the old code would have shown `+1` (nothing removed, one added on top).

**`ThemeListeners` unbounded growth**: `onTheme`/`themed` push into a flat array that nothing ever prunes (the code's own old comment called this "fine for a UI library's lifetime" — not true for a project whose own dev loop re-executes the script constantly). `CreateWindow` now resets `ThemeListeners = {}` before building the new window, bounding it to whatever's actually alive.

**`Library.Flags` outliving a destroyed window**: a flag not reused by a newly-recreated window used to sit forever in `Library.Flags`, pointing at destroyed widgets and polluting `SaveConfig`'s output. `CreateWindow` now resets `self.Flags = {}` up front. Verified live: window #1 (8 flagged widgets) → window #2 (1 new flagged widget) → `Library.Flags` has exactly 1 entry, not 9.

**Slider `Range = {x, x}` (min == max)**: divided by zero in the initial fill size and every `setFromAlpha` call, producing a NaN that `UDim2.fromScale` rejects outright. Fixed with a `toAlpha(v)` helper that returns a fixed `0` for a degenerate range instead of propagating NaN.

**Slider `Increment <= 0`**: divided by zero on every single drag frame (not just at creation, unlike the above). Fixed by falling back to an unquantized/continuous value (`math.clamp(raw, min, max)`) instead of the snap-to-increment math whenever `increment` isn't a valid positive number.

**Slider `CurrentValue` outside `[min, max]`**: the initial `value` was never clamped (unlike every later interaction, which already clamps via `setFromAlpha`) — a bad default rendered the fill bar overflowing the track until the first drag silently fixed it. Now clamped immediately: `local value = math.clamp(config.CurrentValue or min, min, max)`.

**Dropdown `Set()` accepted any string**: no membership check against the widget's actual `Options` — passing a value that isn't a real option displayed it anyway with no option highlighted, and any callback written as an `if/elseif` chain over known options would just silently fall through. Fixed by reusing `optLabels` (already keyed by every valid option, built for the highlight-on-select logic) as a free membership check; `Set` on an unrecognized option now silently no-ops instead of accepting it.

**MultiDropdown `Set(nil)` crashed**: `ipairs(nil)` throws rather than iterating zero times. A `nil` argument — a completely reasonable way to ask for "clear every selection" — now normalizes to `{}` instead of erroring.

**Keybind: invalid key name crashed**: `Enum.KeyCode["NotARealName"]` **throws**, it doesn't return `nil` — so a typo'd `CurrentKeybind` at construction time, or a direct `:Set("BadName")` call, crashed outright (this was already accidentally safe when it came through `LoadConfig`, since that path wraps every `Set` in its own `pcall` — this fix protects the two paths that weren't wrapped by anything). Added a `safeKeyCode` helper that `pcall`s the `Enum.KeyCode[...]` lookup and returns `nil` on a bad name instead of propagating the throw.

**`DeleteConfig` couldn't distinguish "deleted" from "was never there"**: some executors' `delfile` silently no-ops on a nonexistent path instead of erroring, so the function could return `true` for a delete that didn't actually happen. Added an `isfile` pre-check (itself `pcall`-guarded, so it degrades gracefully on an executor without `isfile`) so a nonexistent name now correctly returns `false, "no such config: ..."`.

**Not changed — `SaveConfig`'s folder check was already fine**: the review flagged `SaveConfig` for "not checking the folder," but it already calls `ensureConfigFolder()` before writing; it just doesn't gate on that call's own boolean result, and the `writefile` right after is independently `pcall`-wrapped and already reports failure gracefully. Left as-is — there was nothing here that actually broke.

**Follow-up (same session): the connection-leak fix above only covered half the real problem.** `GlobalConnections` being a plain `local` means it only helps when `CreateWindow` is called twice against the *same* loaded `Library` instance — it did nothing for the far more common case of the whole script being re-executed from scratch (pressing "Execute" again in an executor), since a fresh `loadstring(...)()` call creates a brand new chunk with its own empty `GlobalConnections`, with no Lua-level path back to the *previous* execution's connections at all. Those old connections don't care that the script that made them is gone, though — they live on `UserInputService`'s own signal, not in anything the new execution can reach or garbage-collect. Fixed by backing `GlobalConnections` with `getgenv()` (a standard executor API for exactly this: state that survives a fresh script load, unlike ordinary locals) — module load time now disconnects whatever a previous execution left in `genv.__IOSRobloxUILibConnections` before starting this execution's own fresh list. Falls back to a plain local on an executor without `getgenv()` (same-instance cleanup still works, cross-execution just can't). `clearGlobalConnections` clears the table *in place* rather than rebinding it, so the `genv` reference and the local upvalue never diverge. Verified live with two genuinely separate `loadstring()` executions (not two `CreateWindow` calls in one) — execution #1 left a keybind connection alive with no cleanup of its own; execution #2's `CreateWindow` correctly found and disconnected it via `genv` before adding its own, net delta 0 across the two.

## 17. `Library:Destroy()` / `Window:Destroy()`

Full explicit teardown, complementing (not replacing) the implicit cleanup `CreateWindow` already does before building a new window. `Library:Destroy()` calls `clearGlobalConnections()` (see §16 — this also catches a previous full script execution's leftover connections via `getgenv()`), resets `ThemeListeners` and `Flags`, and destroys the GUI — found by name (`guiParent:FindFirstChild("IOSRobloxUILib")`), the same way `CreateWindow` finds a previous window to replace, rather than via `self.Window` alone, so it still works even if that reference was never set (e.g. `Destroy()` called on a freshly-loaded instance before `CreateWindow` has run on it). `Window:Destroy()` is a one-line convenience alias delegating straight to `Library:Destroy()`, for a script that kept its own `Window` variable instead of the `Library` one.

Deliberately does **not** touch the independent Notify toast layer (§9) — that's decoupled from any Window's lifecycle by design, so a script can still `Library:Notify(...)` after `Destroy()` without needing to re-`CreateWindow` first.

Verified live: destroying removed the GUI (`FindFirstChild("IOSRobloxUILib")` became `nil`) and brought the tracked connection count back down to baseline (confirmed via `#getconnections(UserInputService.InputBegan)` before/after).

## 18. Window Resize (Drag Corner Handle)

`WindowMinSize` (400, 280) and `WindowMaxSize` (900, 700) constants sit alongside `WindowSize`. A small `ResizeHandle` `TextButton` (18x18, invisible background, hand-drawn 6-dot triangular grip icon) sits anchored to the sheet's bottom-right corner, inset by `Radius.Sheet - 2` rather than a couple pixels — `ClipsDescendants` only clips to the sheet's rectangular bounds, not its rounded silhouette, so a corner-anchored control needs that inset to read as part of the sheet instead of visually poking past the rounded edge.

Same offset-accumulation drag idiom as the header drag (§8), but grows/shrinks `sheet.Size` instead of moving `sheet.Position`, with both axes independently `math.clamp`'d to `WindowMinSize`/`WindowMaxSize`. Nothing downstream needed any changes to support live resizing — Dock/Content/Pages/tab rows are already Scale-relative to `sheet`, and `positionFlyout` already reads `sheet.AbsoluteSize` fresh at open-time (built that way originally for the dock-collapse/expand tween).

Verified live via `getconnections():Fire()` on the handle's `InputBegan` plus the global `UserInputService.InputChanged`/`InputEnded` (same technique as §17): a +100/+80 drag grew the sheet from 454x451 to exactly 554x531; a -2000/-2000 drag clamped to the 400x280 floor; a +5000/+5000 drag clamped to the 900x700 ceiling. Zero console errors across the whole pass.

## 19. Code Review Pass (Aug 30, 2026) — Static Findings + Fixes

A full line-by-line static review (MCP disconnected for this pass — no live client, fixes applied but NOT yet verified live) against a checklist of suspected problem areas, cross-referenced with what §16/§17 had already fixed. Confirmed and fixed:

- **Dropdown/MultiDropdown had no way to change `Options` after creation.** Both now expose `control:Refresh(newOptions)`, following the exact rebuild-in-place pattern `CreateConfigManager`'s `rebuildRows` already established. The option-building loop in each was pulled out into its own `rebuildOptions()` function so the initial build and `Refresh` share one code path instead of two. Dropdown falls back to the new first option if `current` isn't in the refreshed list; MultiDropdown drops any now-invalid selections from `selected`.
- **No common lifecycle across controls.** Every `CreateXxx` now returns (or, for Label/Button, now returns a table instead of a bare Frame) a control with `SetVisible(bool)`, `SetEnabled(bool)`, `SetName(str)`, `SetDescription(str)`, `Destroy()` — attached in one place (`attachLifecycle`, sits right after `labelBlock`) instead of reimplemented per widget. `SetEnabled` toggles a `DisabledOverlay` frame `baseRow` now builds into every row (dim + `Active=true` to actually block input, `Visible=false` by default so an always-enabled control pays nothing extra). `SetDescription` lazily creates a description label if the widget started without one. Widgets with no label-block concept (Button/Label/Slider) get `SetDescription` as a documented no-op rather than a crash. `Destroy` also drops the control from `Library.Flags` if it was flagged — for Dropdown/MultiDropdown/ColorPicker/ConfigManager, which are the four widgets with an `Overlay`-parented flyout that is NOT a child of `row`, `Destroy` is overridden to additionally destroy the flyout Instance and disconnect its `sheet`-rooted reposition connection (see next finding) — `row:Destroy()` alone would have orphaned both.
- **`Keybind.ChangedCallback` fired on manual rebind but not on `Set()`/`LoadConfig`.** `Set()` now also fires `changedCallback` (still deliberately NOT firing the main action `callback` — that would misfire the bound action itself on every config load).
- **`NumbersOnly` only filtered characters, never validated the result.** `"1.2.3"`, `"--5"`, `"5-"`, `"."`, `"-"` all previously survived the character filter intact. `commit()` in `CreateInput` now runs the filtered text through `tonumber()` and reverts to the last known-good value on failure — same snap-back-on-invalid idiom the color picker's own hex box already used.
- **Slider `Range` reversed (`{200, 16}`) crashed.** `math.clamp` requires `min <= max`; now swapped defensively at the top of `CreateSlider`, same spirit as the existing `max==min`/`increment<=0` guards right below it.
- **Clicking a slider track without dragging did nothing.** `trackButton.MouseButton1Down` now calls `setFromAlpha` immediately with the click position, instead of only flipping the `dragging` flag and waiting for a move event that a plain click never produces.
- **An open flyout (Dropdown/MultiDropdown/ColorPicker/ConfigManager) didn't follow the anchor button if the layout changed while open** — collapsing the dock, or dragging the new (§18) resize handle, left it visually stranded at its open-time position. Each now connects `anchorBtn:GetPropertyChangedSignal("AbsolutePosition")` and `sheet:GetPropertyChangedSignal("AbsoluteSize")` to a `reposition()` closure that re-calls `positionFlyout` live while open.
- **`IOSRobloxUILibNotify` (the toast layer) leaked one orphaned ScreenGui per full script re-execution.** Unlike `"IOSRobloxUILib"` itself, which `CreateWindow` finds-and-destroys by name before building a new one, `ensureNotifyLayer` only checked its own local `notifyGui`/`notifyStack` variables — which start `nil` on a fresh `loadstring()` with no idea a previous execution's notify GUI is still sitting in `guiParent`. Now does the same find-by-name-and-destroy `CreateWindow` already does.

**Verified live** once MCP reconnected, via a series of throwaway `loadstring(readfile("library.lua"))()` probes (each ending in `Library:Destroy()`, never touching the actual `testhub.lua` demo window except transiently) rather than UI clicks, since most of these are Lua-API-level behaviors (`Refresh`, `SetEnabled`, `Destroy`) that don't have a click surface to fire:

- `Dropdown:Refresh()`: confirmed the rebuild + Set-membership-check works — but caught a REAL bug in the first draft during this pass: the "is `current` still valid" check ran BEFORE `rebuildOptions()`, against the STALE `optLabels` (still keyed by the OLD options), so a `current` that became invalid after a refresh incorrectly survived (old table still said "yes I know this"). Fixed by moving the check to after `rebuildOptions()`, against the freshly-rebuilt table. Re-verified: refreshing `{"A","B","C"}` (current "A") to `{"X","Y","Z"}` now correctly falls back to `"X"`.
- `SetEnabled(false)`: confirmed the `DisabledOverlay` becomes `Visible=true` (and back to `false` on re-enable) — this verifies the overlay's *state*, not a real blocked click (`getconnections():Fire()` invokes the Lua callback directly, bypassing hit-testing entirely, so it can't prove input-blocking either way; the technique itself — `Active=true`, higher ZIndex, full coverage — is a standard, reliable Roblox pattern, just not directly provable through this test harness).
- `Keybind:Set()` firing `ChangedCallback`: confirmed — set to `"Q"`, `ChangedCallback` fired with `"Q"`, main `Callback` correctly did NOT fire.
- `NumbersOnly`: confirmed — `Set("1.2.3")` on a `CurrentValue="42"` input reverted to `"42"`; `Set("99.5")` (structurally valid) was accepted.
- Slider reversed `Range={200,16}`: confirmed no crash; `Set(5)` clamped to `16` (real min post-swap), `Set(500)` clamped to `200` (real max post-swap).
- Slider click-without-drag: confirmed — firing `trackButton.MouseButton1Down` at 25% along the track jumped the value to exactly `min + 0.25*(max-min)` with zero drag events.
- Flyout reposition on window resize: confirmed, but only once the test waited long enough (~1s) for `GetPropertyChangedSignal("AbsoluteSize")` to actually fire in this executor — an initial 0.05s wait produced a false negative (position genuinely hadn't been recomputed yet, not a broken connection; `#getconnections(...)` confirmed exactly 1 listener registered).
- Flyout reposition on dock-collapse: **this specific trigger turns out not to be a real bug at all** — every flyout-anchor button (`Dropdown`/`MultiDropdown`/`ColorPicker`'s swatch/`ConfigManager`'s selectBtn) is right-anchored (`AnchorPoint(1,0.5)`, `Position=UDim2.new(1,0,0.5,0)`) inside a row that fills 100% of `content`'s width. Collapsing the dock shifts `content`'s left edge and grows its width by the exact same amount, so `content`'s (and therefore the row's, therefore the button's) RIGHT edge never moves — confirmed live: `btn.AbsolutePosition` was bit-for-bit identical before and after firing the dock-collapse click. The original static-review claim conflated this with the resize-handle case; only the resize-handle drift was ever real. The reposition hook is harmless to keep regardless (it's what correctly catches the resize case, and costs nothing for a case that never fires).
- `IOSRobloxUILibNotify` no longer accumulates: 3 separate fresh `loadstring()` executions, each calling `:Notify()`, held the count at exactly 1 throughout (searched via `gethui()`, which is what `getGuiParent()` actually resolves to on this executor — a hashed folder under `CoreGui`, not `CoreGui` itself).
- `Destroy()` on Dropdown/MultiDropdown/ColorPicker: confirmed the overridden `Destroy` removes the `OptionList`/panel from `Overlay` (not just the row) and drops the flag from `Library.Flags` — this was the gap caught mid-session before ever shipping, see the entry above.

Restored `testhub.lua` as the live demo afterward (exactly one `IOSRobloxUILib` confirmed, zero console errors); cleaned up all throwaway probe/seed scripts.

## 20. Tier 1 Enhancements Batch (Aug 31, 2026)

Implementation and live verification of the Tier 1 roadmap batch across all widgets:

1. **Widget `.Type` Introspection String**:
   - Added a static `.Type` field across all 13 widget return tables: `"Button"`, `"Toggle"`, `"Slider"`, `"Dropdown"`, `"MultiDropdown"`, `"ColorPicker"`, `"Input"`, `"Keybind"`, `"Label"`, `"Divider"`, `"ProgressBar"`, `"Section"`, `"ConfigManager"`.
   - Enables runtime type introspection and automated configuration serialization.

2. **`CreateDivider` (Tab & Section)**:
   - Minimalist 1px hairline horizontal rule (`Radius.Pill` corner, `Colors.Separator` background).
   - Fully integrated with unified lifecycle methods (`attachLifecycle`, `.Type = "Divider"`).

3. **`CreateProgressBar` (Tab & Section)**:
   - Visual progress bar widget with rounded track, animated fill (`Colors.Accent`), percentage/custom text display, and smooth tweening.
   - Methods: `SetProgress(fraction, animate)`, `GetProgress()`, `SetText(overrideText)`, plus standard `attachLifecycle` methods.
   - Registers in `Library.Flags` when a `Flag` is specified, enabling retrieval via `Library:GetControl`.

4. **`Library:GetControl(flagName)`**:
   - Flag lookup helper that searches `Library.Flags[flagName]`. Emits a `warn()` diagnostic if the flag does not exist or has not been registered.

5. **Slider Click-to-Edit Numerical Input**:
   - Replaced the static slider value label with an interactive `TextBox` (`ClearTextOnFocus = false`).
   - On `FocusLost`, validates input with `tonumber()`, clamps to `[min, max]`, snaps to `Increment`, repositions the fill track, and triggers the callback. Reverts cleanly on invalid input.

## 21. Tier 2 Enhancements Batch (Aug 31, 2026)

Implementation and live verification of the Tier 2 roadmap batch across theming, tabs, dropdowns, and widgets:

1. **Dynamic Custom Theme Registration (`Library:RegisterTheme`)**:
   - `Library:RegisterTheme(name, tokens)` adds or extends theme palettes directly in `Library.Themes`.
   - Validates that required base color keys are present (or falls back to `Dark` theme defaults).
   - Allows instant switching via `Library:SetTheme(name)`.

2. **Dynamic Accent Color Override (`Library:SetAccent`)**:
   - `Library:SetAccent(color3)` dynamically overrides `Colors.AccentBlue` in the central palette.
   - Automatically invokes all registered `ThemeListeners`, immediately retinting active toggles, sliders, active tab buttons, notifications, and accents without a full theme reload.

3. **Programmatic Tab Navigation (`SetActiveTab` & `Activate`)**:
   - `Window:SetActiveTab(target)` supports tab switching by Tab object reference, case-insensitive string name, or 1-based index.
   - `Tab:Activate()` alias method directly on tab instances to trigger smooth activation.
   - Accurately executes selection animations, indicator repositioning, page swapping, and dock state updates.

4. **Tab Notification Badges (`Tab:SetBadge`)**:
   - `Tab:SetBadge(badgeValue)` displays an iOS-style red pill notification badge (`Colors.AccentRed`, auto-width, 10px text, `Radius.Pill`) anchored to the top-right of the dock slot button.
   - Passing `nil`, `""`, `false`, or `0` hides and destroys the badge.
   - Handles numeric values (e.g. `99+` overflow format for numbers > 99) as well as custom strings (e.g. `"NEW"`).

5. **`CreateParagraph` Widget (Tab & Section)**:
   - Rich multi-line content presentation card supporting both `Title` and `Content` (body) strings.
   - Configured with `AutomaticSize = Enum.AutomaticSize.Y` and `TextWrapped = true` to fluidly adapt to arbitrary text lengths without clipping or manual height management.
   - Methods: `SetTitle(text)`, `SetContent(text)`, `SetText(text)`, `SetDescription(text)`, `Set(title, content)`, `Get()`, plus standard `attachLifecycle` methods and `.Type = "Paragraph"`.

6. **Searchable & Scrolling Dropdowns (`CreateDropdown` & `CreateMultiDropdown`)**:
   - Added `Searchable = true` support to both single-select and multi-select dropdown flyouts.
   - Introduces an embedded search `TextBox` header in the flyout with real-time text query filtering.
   - Wraps option items in a native `ScrollingFrame` with dynamic `CanvasSize` and configurable `MaxVisible` row height clamping.
   - Resets search query and displays all options automatically each time the dropdown is opened.


