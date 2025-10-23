# Fueki Rebranding - Color Implementation Priority List

## Phase 1: Primary Brand Colors (HIGH PRIORITY - DO FIRST)

**Estimated Time**: 30 minutes
**Risk Level**: 🟢 Low
**Impact**: High visibility

### Asset Catalog Updates

1. **Stronbuy.colorset** → Fueki Primary
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Stronbuy.colorset/Contents.json`
   - Change: `#1A60FF` → `#2563EB`
   - RGB: `{ red: 0x25, green: 0x63, blue: 0xEB }`

2. **Laguna.colorset** → Fueki Secondary
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Laguna.colorset/Contents.json`
   - Light mode: `#4692DA` → `#3B82F6`
   - Dark mode: `#4A98E9` → `#3B82F6`
   - RGB: `{ red: 0x3B, green: 0x82, blue: 0xF6 }`

### Swift Code Updates

3. **Colors.swift**
   - File: `/UnstoppableWallet/UnstoppableWallet/UserInterface/ThemeKit/Colors.swift`
   - Line 93: `static let themeStronbuy = UIColor(hex: 0x1A60FF)` → `UIColor(hex: 0x2563EB)`
   - Line 96: `static let themeLagunaD = UIColor(hex: 0x4A98E9)` → `UIColor(hex: 0x3B82F6)`
   - Line 97: `static let themeLagunaL = UIColor(hex: 0x4692DA)` → `UIColor(hex: 0x3B82F6)`

### Testing Checklist

- [ ] Primary buttons render with new Fueki blue
- [ ] Links and interactive elements use new color
- [ ] Focus states and selections appear correct
- [ ] Light and dark mode both work
- [ ] No visual regressions on main screens

---

## Phase 2: Background Colors (MEDIUM PRIORITY)

**Estimated Time**: 1 hour
**Risk Level**: 🟢 Low
**Impact**: Overall aesthetic shift

### Asset Catalog Updates

4. **Darker.colorset** → Slate 950
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Darker.colorset/Contents.json`
   - Change: `#0F1014` → `#0F172A`
   - RGB: `{ red: 0x0F, green: 0x17, blue: 0x2A }`

5. **Dark.colorset** → Slate 900
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Dark.colorset/Contents.json`
   - Change: `#151515` → `#1E293B`
   - RGB: `{ red: 0x1E, green: 0x29, blue: 0x3B }`

6. **Carbon.colorset** → Slate 800
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Carbon.colorset/Contents.json`
   - Change: `#1C1C1E` → `#334155`
   - RGB: `{ red: 0x33, green: 0x41, blue: 0x55 }`

7. **Smoke.colorset** → Slate 700
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Smoke.colorset/Contents.json`
   - Change: `#252933` → `#475569`
   - RGB: `{ red: 0x47, green: 0x55, blue: 0x69 }`

### Swift Code Updates

8. **Colors.swift** (if needed)
   - File: `/UnstoppableWallet/UnstoppableWallet/UserInterface/ThemeKit/Colors.swift`
   - Line 77: `static let themeDarker = UIColor(hex: 0x0F1014)` → `UIColor(hex: 0x0F172A)`
   - Line 75: `static let themeSteelDark = UIColor(hex: 0x252933)` → `UIColor(hex: 0x475569)`

### Testing Checklist

- [ ] App background has warmer, blue-gray tone
- [ ] Card backgrounds are clearly elevated
- [ ] Modal and popover backgrounds render correctly
- [ ] Depth perception improved between layers
- [ ] No text readability issues

---

## Phase 3: Text & UI Colors (MEDIUM PRIORITY)

**Estimated Time**: 2 hours
**Risk Level**: 🟡 Medium (requires contrast testing)
**Impact**: Text readability across app

### Asset Catalog Updates

9. **Steel.colorset** → Slate 600
   - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Steel.colorset/Contents.json`
   - Change: `#73798C` → `#64748B`
   - RGB: `{ red: 0x64, green: 0x74, blue: 0x8B }`

10. **Gray.colorset** → Slate 500
    - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Gray.colorset/Contents.json`
    - Change: `#808085` → `#94A3B8`
    - RGB: `{ red: 0x94, green: 0xA3, blue: 0xB8 }`

11. **SteelLight.colorset** → Slate 300
    - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/SteelLight.colorset/Contents.json`
    - Change: `#E1E1E5` → `#E2E8F0`
    - RGB: `{ red: 0xE2, green: 0xE8, blue: 0xF0 }`

12. **LightGray.colorset** → Slate 400
    - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/LightGray.colorset/Contents.json`
    - Change: `#C8C7CC` → `#CBD5E1`
    - RGB: `{ red: 0xCB, green: 0xD5, blue: 0xE1 }`

### Swift Code Updates

13. **Colors.swift**
    - File: `/UnstoppableWallet/UnstoppableWallet/UserInterface/ThemeKit/Colors.swift`
    - Line 76: `static let themeSteelLight = UIColor(hex: 0xE1E1E5)` → `UIColor(hex: 0xE2E8F0)`
    - Line 74: `static let themeLightGray = UIColor(hex: 0xC8C7CC)` → `UIColor(hex: 0xCBD5E1)`

### Testing Checklist

- [ ] Run automated contrast ratio checks
- [ ] Verify all text is readable on dark backgrounds
- [ ] Check secondary text visibility
- [ ] Test border and divider visibility
- [ ] Verify placeholder text contrast
- [ ] Test disabled state visibility

---

## Phase 4: Status Colors (LOW PRIORITY - Optional)

**Estimated Time**: 1 hour
**Risk Level**: 🟢 Low
**Impact**: Status indicator aesthetics

### Asset Catalog Updates

14. **Green.colorset** → Success
    - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Green.colorset/Contents.json`
    - Change: `#0AC18E` → `#10B981`
    - RGB: `{ red: 0x10, green: 0xB9, blue: 0x81 }`

15. **Yellow.colorset** → Warning
    - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Yellow.colorset/Contents.json`
    - Change: `#FFB700` → `#F59E0B`
    - RGB: `{ red: 0xF5, green: 0x9E, blue: 0x0B }`

16. **Red.colorset** → Danger
    - File: `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Red.colorset/Contents.json`
    - Change: `#FF1539` → `#EF4444`
    - RGB: `{ red: 0xEF, green: 0x44, blue: 0x44 }`

### Swift Code Updates

17. **Colors.swift**
    - File: `/UnstoppableWallet/UnstoppableWallet/UserInterface/ThemeKit/Colors.swift`
    - Line 63: `static let themeYellowD = UIColor(hex: 0xFFB700)` → `UIColor(hex: 0xF59E0B)`
    - Line 64: `static let themeYellowL = UIColor(hex: 0xFF9D00)` → `UIColor(hex: 0xF59E0B)`
    - Line 65: `static let themeGreenD = UIColor(hex: 0x0AC18E)` → `UIColor(hex: 0x10B981)`
    - Line 66: `static let themeGreenL = UIColor(hex: 0x0AA177)` → `UIColor(hex: 0x10B981)`
    - Line 67: `static let themeRedD = UIColor(hex: 0xFF1539)` → `UIColor(hex: 0xEF4444)`
    - Line 68: `static let themeRedL = UIColor(hex: 0xFF1500)` → `UIColor(hex: 0xEF4444)`

### Testing Checklist

- [ ] Success messages display correctly
- [ ] Warning indicators are visible
- [ ] Error states are prominent
- [ ] Alert colors remain distinguishable
- [ ] Chart colors work together

---

## Phase 5: Character Colors (HIGH COMPLEXITY - Review Required)

**Estimated Time**: 4-6 hours
**Risk Level**: 🔴 High
**Impact**: Varies by color usage

### Analysis Required First

Before updating character colors, analyze their usage:

```bash
# Find all references to each character color
grep -r "\.themeTyler\|\.themeLawrence\|\.themeAndy\|\.themeLeah" --include="*.swift" | wc -l
```

### Character Colors to Review (61 total)

**Background System**:
- Tyler, Tyler96, Lawrence, Blade, Andy, Leah

**UI Elements**:
- Jeremy, Claude, Helsing, Nina, Raina, Bran

**Status** (already mapped):
- Jacob (Yellow), Remus (Green), Lucian (Red)

**Special**:
- BlackTenTwenty, Laguna (already updated)

### Approach

1. **Map usage**: For each character color, determine semantic meaning
2. **Update underlying colorset**: Change Contents.json to new Fueki/Slate values
3. **Preserve Swift references**: Keep character names, update values
4. **Test extensively**: Check all UI states

### Example

Tyler is used as base background:
```swift
static var themeTyler: UIColor {
  color(dark: .black, light: .themeBright)
}
```

To update:
1. Keep Swift code unchanged
2. Update `Colors.xcassets/Tyler.colorset` dark variant: `#000000` → `#0F172A` (Slate 950)
3. Test all screens using Tyler background

---

## Implementation Workflow

### Step 1: Backup Current State

```bash
cd /Users/computer/Downloads/unstoppable-wallet-ios-master
git checkout -b fueki-color-rebrand
git add -A
git commit -m "Backup: Pre-Fueki color system"
```

### Step 2: Execute Phase 1 (Brand Colors)

```bash
# Update colorsets (manual JSON editing)
# Update Colors.swift (lines 93, 96-97)
git add -A
git commit -m "Phase 1: Update primary brand colors to Fueki palette"
```

### Step 3: Build & Test

```bash
xcodebuild -workspace UnstoppableWallet.xcworkspace \
  -scheme UnstoppableWallet \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

### Step 4: Visual Testing

- Open in Xcode
- Run on simulator
- Test light mode
- Test dark mode
- Screenshot comparison

### Step 5: Repeat for Each Phase

Continue with Phases 2-4, testing after each phase.

---

## Rollback Plan

If issues arise:

```bash
# Revert to pre-Fueki state
git checkout main
git branch -D fueki-color-rebrand

# Or revert specific files
git checkout main -- UnstoppableWallet/UnstoppableWallet/Colors.xcassets
git checkout main -- UnstoppableWallet/UnstoppableWallet/UserInterface/ThemeKit/Colors.swift
```

---

## Success Metrics

After implementation, verify:

- ✅ All primary blue elements use Fueki Primary (#2563EB)
- ✅ Backgrounds have warmer, slate tone
- ✅ Text contrast ratios meet WCAG AA (4.5:1 minimum)
- ✅ Status indicators remain distinguishable
- ✅ Light and dark modes both render correctly
- ✅ No visual regressions in critical flows
- ✅ App builds without errors
- ✅ All tests pass

---

## Dependencies for Other Agents

**Logo Designer** can proceed with:
- Fueki Primary: #2563EB
- Fueki Secondary: #3B82F6
- Background: Slate 900 (#1E293B)

**Code Implementation** needs:
- Complete Phase 1 before logo integration
- Coordinate with Testing for regression checks

**Testing** should:
- Prepare screenshot baselines before changes
- Set up automated contrast checking
- Create device test matrix

---

**Next Action**: Begin Phase 1 implementation (Stronbuy → Fueki Primary)
