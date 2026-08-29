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
