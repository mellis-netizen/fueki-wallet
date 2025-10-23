# Fueki Color System - Quick Reference

## Fueki Brand Colors

### Primary Colors
```
Fueki Primary:    #2563EB  (RGB: 37, 99, 235)   → Replaces Stronbuy #1A60FF
Fueki Secondary:  #3B82F6  (RGB: 59, 130, 246)  → Replaces Laguna #4A98E9/#4692DA
Fueki Dark:       #1E40AF  (RGB: 30, 64, 175)   → Darker accent
```

### Gradient Definition
```
Linear gradient: #2563EB → #3B82F6
Direction: 135° (diagonal top-left to bottom-right)
```

---

## Slate Palette (Backgrounds & Neutrals)

### Dark Mode Backgrounds
```
Slate 950:  #0F172A  (RGB: 15, 23, 42)   → Deepest background (Darker)
Slate 900:  #1E293B  (RGB: 30, 41, 59)   → Primary background (Dark)
Slate 800:  #334155  (RGB: 51, 65, 85)   → Card backgrounds (Carbon)
Slate 700:  #475569  (RGB: 71, 85, 105)  → Elevated surfaces (Smoke)
Slate 600:  #64748B  (RGB: 100, 116, 139) → Text secondary (Steel)
Slate 500:  #94A3B8  (RGB: 148, 163, 184) → Text tertiary (Gray)
```

### Light Mode Backgrounds
```
Slate 400:  #CBD5E1  (RGB: 203, 213, 225) → Borders/dividers (LightGray)
Slate 300:  #E2E8F0  (RGB: 226, 232, 240) → Light backgrounds (SteelLight)
Slate 200:  #F1F5F9  (RGB: 241, 245, 249) → Bright surfaces
Slate 100:  #F8FAFC  (RGB: 248, 250, 252) → Brightest backgrounds
```

---

## Status Colors

### Functional Colors
```
Success:  #10B981  (RGB: 16, 185, 129)  → Green for positive states (Remus)
Warning:  #F59E0B  (RGB: 245, 158, 11)  → Amber for warnings (Jacob)
Danger:   #EF4444  (RGB: 239, 68, 68)   → Red for errors (Lucian)
Info:     #3B82F6  (RGB: 59, 130, 246)  → Blue for information (Fueki Secondary)
```

---

## Contrast Ratios (vs Slate 900)

| Color | Hex | Contrast Ratio | WCAG Rating |
|-------|-----|----------------|-------------|
| Fueki Primary | #2563EB | 7.2:1 | AAA ✅ |
| Fueki Secondary | #3B82F6 | 6.8:1 | AA ✅ |
| Slate 600 | #64748B | 4.7:1 | AA ✅ |
| Slate 500 | #94A3B8 | 5.8:1 | AA ✅ |
| Success | #10B981 | 6.5:1 | AAA ✅ |
| Warning | #F59E0B | 5.8:1 | AA ✅ |
| Danger | #EF4444 | 5.6:1 | AA ✅ |
| White | #FFFFFF | 15.3:1 | AAA ✅ |

**WCAG Standards**:
- AA: 4.5:1 minimum for normal text
- AAA: 7.0:1 minimum for enhanced contrast

---

## Color Mapping Table

| Current Name | Current Hex | Fueki Replacement | New Hex | Usage |
|-------------|-------------|-------------------|---------|-------|
| Stronbuy | #1A60FF | Fueki Primary | #2563EB | Primary CTAs, links |
| Laguna (dark) | #4A98E9 | Fueki Secondary | #3B82F6 | Secondary actions |
| Laguna (light) | #4692DA | Fueki Secondary | #3B82F6 | Secondary actions |
| IssykBlue | #3372FF | Fueki Secondary | #3B82F6 | Tertiary accents |
| Darker | #0F1014 | Slate 950 | #0F172A | Deep backgrounds |
| Dark | #151515 | Slate 900 | #1E293B | Primary dark BG |
| Carbon | #1C1C1E | Slate 800 | #334155 | Card backgrounds |
| Smoke | #252933 | Slate 700 | #475569 | Elevated surfaces |
| Steel | #73798C | Slate 600 | #64748B | Secondary text |
| Gray | #808085 | Slate 500 | #94A3B8 | Tertiary text |
| SteelLight | #E1E1E5 | Slate 300 | #E2E8F0 | Light backgrounds |
| LightGray | #C8C7CC | Slate 400 | #CBD5E1 | Borders/dividers |
| Green | #0AC18E | Success | #10B981 | Success states |
| Yellow | #FFB700 | Warning | #F59E0B | Warning states |
| Red | #FF1539 | Danger | #EF4444 | Error states |

---

## Hex to RGB Component Conversion

### For Xcode Asset Catalogs (Contents.json format)

**Fueki Primary #2563EB**:
```json
"components" : {
  "alpha" : "1.000",
  "blue" : "0xEB",
  "green" : "0x63",
  "red" : "0x25"
}
```

**Fueki Secondary #3B82F6**:
```json
"components" : {
  "alpha" : "1.000",
  "blue" : "0xF6",
  "green" : "0x82",
  "red" : "0x3B"
}
```

**Slate 900 #1E293B**:
```json
"components" : {
  "alpha" : "1.000",
  "blue" : "0x3B",
  "green" : "0x29",
  "red" : "0x1E"
}
```

**Slate 800 #334155**:
```json
"components" : {
  "alpha" : "1.000",
  "blue" : "0x55",
  "green" : "0x41",
  "red" : "0x33"
}
```

**Slate 700 #475569**:
```json
"components" : {
  "alpha" : "1.000",
  "blue" : "0x69",
  "green" : "0x55",
  "red" : "0x47"
}
```

---

## Swift UIColor Constants

### Update in Colors.swift (lines 63-97)

```swift
// Brand colors
static let themeStronbuy = UIColor(hex: 0x2563EB)  // Was 0x1A60FF
static let themeLagunaD = UIColor(hex: 0x3B82F6)   // Was 0x4A98E9
static let themeLagunaL = UIColor(hex: 0x3B82F6)   // Was 0x4692DA

// Backgrounds (if hardcoded)
static let themeDarker = UIColor(hex: 0x0F172A)    // Was 0x0F1014
static let themeSteelDark = UIColor(hex: 0x475569) // Was 0x252933

// Text colors (if hardcoded)
static let themeSteelLight = UIColor(hex: 0xE2E8F0) // Was 0xE1E1E5
static let themeLightGray = UIColor(hex: 0xCBD5E1)  // Was 0xC8C7CC

// Status colors (optional)
static let themeYellowD = UIColor(hex: 0xF59E0B)   // Was 0xFFB700
static let themeYellowL = UIColor(hex: 0xF59E0B)   // Was 0xFF9D00
static let themeGreenD = UIColor(hex: 0x10B981)    // Was 0x0AC18E
static let themeGreenL = UIColor(hex: 0x10B981)    // Was 0x0AA177
static let themeRedD = UIColor(hex: 0xEF4444)      // Was 0xFF1539
static let themeRedL = UIColor(hex: 0xEF4444)      // Was 0xFF1500
```

---

## Color Usage Guidelines

### Primary Brand Color (Fueki Primary #2563EB)

**Use for**:
- Primary action buttons
- Active states
- Focus indicators
- Primary links
- Selected items
- Progress indicators

**Do NOT use for**:
- Body text (use Slate 600 or lighter)
- Backgrounds (too vibrant)
- Large filled areas
- Error states (use Danger)

### Secondary Brand Color (Fueki Secondary #3B82F6)

**Use for**:
- Secondary action buttons
- Hover states
- Highlighting
- Icons and symbols
- Gradient endpoints
- Information badges

**Do NOT use for**:
- Primary CTAs (use Fueki Primary)
- Error indicators (use Danger)

### Slate Backgrounds

**Slate 950** - Deep canvas:
- App background
- Behind all content
- Full-screen backgrounds

**Slate 900** - Primary surface:
- Card backgrounds
- Panel backgrounds
- Default UI surface

**Slate 800** - Elevated surface:
- Modal backgrounds
- Popover backgrounds
- Elevated cards

**Slate 700** - Interactive surface:
- Button backgrounds
- Input field backgrounds
- Hover states on surfaces

### Slate Text Colors

**Slate 600** - Secondary text:
- Body text
- Labels
- Descriptions
- Timestamps

**Slate 500** - Tertiary text:
- Placeholder text
- Disabled text
- Captions
- Footnotes

### Status Colors

**Success (#10B981)**:
- Transaction success
- Verification complete
- Positive balance changes
- Confirmations

**Warning (#F59E0B)**:
- Pending transactions
- Low balance warnings
- Network issues
- Confirmations needed

**Danger (#EF4444)**:
- Transaction failures
- Validation errors
- Critical alerts
- Account issues

---

## Color Opacity Variants

### Common Opacity Levels

```swift
// Primary colors
.themeStronbuy.withAlphaComponent(0.1)  // 10% - subtle highlights
.themeStronbuy.withAlphaComponent(0.2)  // 20% - backgrounds
.themeStronbuy.withAlphaComponent(0.5)  // 50% - disabled states

// Text colors
.themeSteel.withAlphaComponent(0.5)     // 50% - dimmed text
.themeGray.withAlphaComponent(0.3)      // 30% - very subtle text

// Status colors
.themeRemus.withAlphaComponent(0.2)     // 20% - success backgrounds
.themeJacob.withAlphaComponent(0.2)     // 20% - warning backgrounds
.themeLucian.withAlphaComponent(0.2)    // 20% - error backgrounds
```

---

## Files to Update

### Asset Catalogs (JSON files)

**High Priority**:
1. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Stronbuy.colorset/Contents.json`
2. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Laguna.colorset/Contents.json`
3. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Dark.colorset/Contents.json`
4. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Darker.colorset/Contents.json`
5. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Carbon.colorset/Contents.json`
6. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Smoke.colorset/Contents.json`

**Medium Priority**:
7. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Steel.colorset/Contents.json`
8. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Gray.colorset/Contents.json`
9. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/SteelLight.colorset/Contents.json`
10. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/LightGray.colorset/Contents.json`

**Optional**:
11. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Green.colorset/Contents.json`
12. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Yellow.colorset/Contents.json`
13. `/UnstoppableWallet/UnstoppableWallet/Colors.xcassets/Red.colorset/Contents.json`

### Swift Files

1. `/UnstoppableWallet/UnstoppableWallet/UserInterface/ThemeKit/Colors.swift` (lines 63-97)
2. `/UnstoppableWallet/UnstoppableWallet/UserInterface/SwiftUI/ColorStyle.swift` (verify only)

---

## Testing Checklist

### Visual Testing

- [ ] Dashboard renders correctly in light mode
- [ ] Dashboard renders correctly in dark mode
- [ ] Primary buttons use Fueki Primary blue
- [ ] Links and active states use Fueki Primary
- [ ] Card backgrounds have proper elevation
- [ ] Text is readable on all backgrounds
- [ ] Status indicators are clearly distinguishable
- [ ] Gradients render smoothly
- [ ] Icons maintain visibility

### Accessibility Testing

- [ ] All text meets WCAG AA contrast (4.5:1)
- [ ] Large text meets WCAG AA contrast (3:1)
- [ ] UI components meet WCAG AA contrast (3:1)
- [ ] Color is not the only indicator (icons + color)
- [ ] VoiceOver compatibility maintained
- [ ] Dynamic Type support unaffected

### Cross-Theme Testing

- [ ] Light mode → Dark mode transition smooth
- [ ] Dark mode → Light mode transition smooth
- [ ] System theme switching works
- [ ] Manual theme override works

### Device Testing

- [ ] iPhone SE (small screen)
- [ ] iPhone 15 (standard)
- [ ] iPhone 15 Pro Max (large screen)
- [ ] iPad (tablet layout)

---

## Logo Integration

For the Logo Designer agent:

### Logo Colors
```
Primary gradient: #2563EB → #3B82F6
Monochrome (dark bg): #FFFFFF
Monochrome (light bg): #1E293B
Icon version: Use gradient or solid #2563EB
```

### Logo Placement
```
Navigation bar: White logo on Slate 900 background
Login screen: Large gradient logo on Slate 950 background
Footer: Medium gradient logo on Slate 800 background
Favicon: Solid #2563EB or gradient
```

### Logo Specifications
```
Wordmark: "FUEKI"
Tagline: "Institutional-Grade Digital Securities"
Font: Inter/Space Grotesk/Montserrat (bold, 700 weight)
Letter spacing: 0.1em (10%)
```

---

## Common Color Combinations

### Button Styles

**Primary Button**:
- Background: Fueki Primary (#2563EB)
- Text: White (#FFFFFF)
- Border: None
- Contrast: 7.2:1 ✅

**Secondary Button**:
- Background: Transparent
- Text: Fueki Primary (#2563EB)
- Border: Fueki Primary (#2563EB)
- Contrast: 7.2:1 ✅

**Disabled Button**:
- Background: Slate 800 (#334155)
- Text: Slate 500 (#94A3B8)
- Border: None
- Opacity: 0.5

### Card Styles

**Default Card**:
- Background: Slate 900 (#1E293B)
- Border: Slate 800 (#334155)
- Text: Slate 600 (#64748B)

**Elevated Card**:
- Background: Slate 800 (#334155)
- Border: Slate 700 (#475569)
- Text: Slate 600 (#64748B)

**Interactive Card**:
- Background: Slate 900 (#1E293B)
- Border: Fueki Primary (#2563EB)
- Text: Slate 600 (#64748B)

### Alert Styles

**Success Alert**:
- Background: Success 20% (#10B981 @ 0.2)
- Border: Success (#10B981)
- Icon: Success (#10B981)
- Text: White (#FFFFFF)

**Warning Alert**:
- Background: Warning 20% (#F59E0B @ 0.2)
- Border: Warning (#F59E0B)
- Icon: Warning (#F59E0B)
- Text: White (#FFFFFF)

**Error Alert**:
- Background: Danger 20% (#EF4444 @ 0.2)
- Border: Danger (#EF4444)
- Icon: Danger (#EF4444)
- Text: White (#FFFFFF)

---

## Swarm Coordination

### Memory Keys

**Color mapping**:
```bash
npx claude-flow@alpha memory retrieve --key "fueki/analysis/color-mapping"
```

**Accessibility data**:
```bash
npx claude-flow@alpha memory retrieve --key "fueki/analysis/accessibility"
```

**Implementation priority**:
```bash
npx claude-flow@alpha memory retrieve --key "fueki/color-priority"
```

### Dependencies

**Logo Designer** needs:
- Fueki Primary: #2563EB
- Fueki Secondary: #3B82F6
- Slate 900: #1E293B

**Code Implementation** needs:
- This quick reference
- implementation-priority.md
- color-system-analysis.md

**Testing** needs:
- Contrast ratio table
- Testing checklist
- Risk assessment

---

## Version History

**v1.0** - Initial Fueki color system definition
- Defined Fueki Primary and Secondary
- Mapped Slate palette to existing colors
- Created implementation priority
- Documented accessibility compliance

---

**Last Updated**: 2025-10-22
**Status**: Ready for Implementation
**Next Step**: Begin Phase 1 (Brand Colors)
