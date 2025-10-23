# FUEKI Wallet Logo Design Specification
## Professional Octopus Symbol for Multi-Chain Crypto Wallet

---

## 🎨 Design Overview

**Logo Concept**: "The Fueki Octopus"

The Fueki wallet logo features a sophisticated, geometric octopus that represents:
- **Intelligence & Adaptability**: Professional crypto wallet sophistication
- **Multi-Chain Support**: 8 tentacles representing diverse blockchain networks (BTC, ETH, BSC, Polygon, Avalanche, Solana, Arbitrum, Optimism)
- **Security & Trust**: Professional, institutional-grade aesthetic
- **Flow & Connectivity**: Organic tentacles suggesting seamless transactions

---

## 🎯 Design Philosophy

**NOT**: Cartoon, playful, or consumer-grade
**YES**: Professional, geometric, trustworthy, modern

**Inspiration**:
- Kraken exchange (crypto legitimacy) meets Stripe (clean simplicity)
- Bloomberg Terminal (professional) meets modern SaaS (accessible)

---

## 🌈 Official Color Palette

### Primary Colors
- **Fueki Blue**: `#2563EB` - Main brand color, primary octopus
- **Accent Blue**: `#3B82F6` - Gradient end, highlights
- **Deep Slate**: `#0F172A` - Dark background, professional backdrop

### Gradient Definition
```css
linear-gradient(135deg, #2563EB 0%, #3B82F6 100%)
```

### Additional Colors
- **White**: `#FFFFFF` - Eyes, highlights, contrast
- **Light Slate**: `#F8FAFC` - Alternate light background
- **Gray Slate**: `#E2E8F0` - Alternate background gradient

---

## 📐 Logo Variations

### 1. Primary App Icon (Dark Theme)
**File**: `fueki-logo-design.svg`
- Background: Deep Slate (#0F172A)
- Octopus: Blue gradient (#2563EB → #3B82F6)
- 8 flowing tentacles with organic curves
- Intelligent eyes with white highlights
- Suction cup details for texture
- Subtle shadow and glow effects
- 15% padding from edges (iOS safe area)

**Use Cases**:
- Main app icon in App Store
- iPhone/iPad home screen
- Launch screen
- Primary branding

### 2. Simplified Icon (Small Sizes)
**File**: `fueki-logo-simplified.svg`
- Larger body proportions
- Only 5 visible tentacles (higher contrast)
- Bolder stroke widths
- High-contrast eyes
- Optimized for 60x60px to 120x120px

**Use Cases**:
- Notifications
- Settings
- Spotlight search
- Apple Watch

### 3. Alternate Icon (Light Theme)
**File**: `fueki-logo-alternate.svg`
- Light gradient background (#F8FAFC → #E2E8F0)
- Dark slate octopus (#1E293B → #334155)
- Blue accent eyes (#2563EB)
- Inverted color scheme

**Use Cases**:
- Alternative app icon (AppIconAlternate.xcassets)
- Light mode interfaces
- Marketing materials
- Print documents

---

## 📏 Technical Specifications

### File Formats
- **Source**: SVG (scalable vector, no quality loss)
- **Export**: PNG 24-bit RGB
- **Color Space**: sRGB
- **Resolution**: 72 DPI minimum
- **Compression**: Optimized (PNG-8 for solid colors, PNG-24 for gradients)

### iOS Requirements
- **No transparency** on 1024x1024 App Store icon
- **Rounded corners** handled by iOS (don't include in artwork)
- **Safe area padding**: 15% margin from edges
- **Color profile**: sRGB IEC61966-2.1

---

## 📱 Required iOS Icon Sizes

### iPhone Icons
| Size | Scale | Resolution | Filename | Usage |
|------|-------|------------|----------|-------|
| 20×20 | @2x | 40×40 | `fueki-icon-20@2x.png` | Settings |
| 20×20 | @3x | 60×60 | `fueki-icon-20@3x.png` | Settings |
| 29×29 | @2x | 58×58 | `fueki-icon-29@2x.png` | Settings |
| 29×29 | @3x | 87×87 | `fueki-icon-29@3x.png` | Settings |
| 40×40 | @2x | 80×80 | `fueki-icon-40@2x.png` | Spotlight |
| 40×40 | @3x | 120×120 | `fueki-icon-40@3x.png` | Spotlight |
| 60×60 | @2x | 120×120 | `fueki-icon-60@2x.png` | iPhone App |
| 60×60 | @3x | 180×180 | `fueki-icon-60@3x.png` | iPhone App |

### iPad Icons
| Size | Scale | Resolution | Filename | Usage |
|------|-------|------------|----------|-------|
| 20×20 | @1x | 20×20 | `fueki-icon-ipad-20.png` | Notifications |
| 20×20 | @2x | 40×40 | `fueki-icon-ipad-20@2x.png` | Notifications |
| 29×29 | @1x | 29×29 | `fueki-icon-ipad-29.png` | Settings |
| 29×29 | @2x | 58×58 | `fueki-icon-ipad-29@2x.png` | Settings |
| 40×40 | @1x | 40×40 | `fueki-icon-ipad-40.png` | Spotlight |
| 40×40 | @2x | 80×80 | `fueki-icon-ipad-40@2x.png` | Spotlight |
| 76×76 | @1x | 76×76 | `fueki-icon-ipad-76.png` | iPad App |
| 76×76 | @2x | 152×152 | `fueki-icon-ipad-76@2x.png` | iPad App |
| 83.5×83.5 | @2x | 167×167 | `fueki-icon-ipad-83.5@2x.png` | iPad Pro |

### App Store
| Size | Filename | Usage |
|------|----------|-------|
| 1024×1024 | `fueki-icon-1024.png` | App Store (NO alpha channel) |

### Apple Watch (Optional)
| Size | Scale | Resolution | Filename |
|------|-------|------------|----------|
| 24×24 | @2x | 48×48 | `fueki-icon-watch-24@2x.png` |
| 27.5×27.5 | @2x | 55×55 | `fueki-icon-watch-27.5@2x.png` |
| 29×29 | @2x | 58×58 | `fueki-icon-watch-29@2x.png` |
| 29×29 | @3x | 87×87 | `fueki-icon-watch-29@3x.png` |
| 40×40 | @2x | 80×80 | `fueki-icon-watch-40@2x.png` |
| 44×44 | @2x | 88×88 | `fueki-icon-watch-44@2x.png` |
| 50×50 | @2x | 100×100 | `fueki-icon-watch-50@2x.png` |

---

## 🔨 Implementation Instructions

### Step 1: Convert SVG to PNG

**Method A: Using ImageMagick**
```bash
# Install ImageMagick
brew install imagemagick

# Convert primary icon to all sizes
magick -background none fueki-logo-design.svg -resize 1024x1024 fueki-icon-1024.png
magick -background none fueki-logo-design.svg -resize 180x180 fueki-icon-60@3x.png
magick -background none fueki-logo-design.svg -resize 167x167 fueki-icon-ipad-83.5@2x.png

# Convert simplified icon for small sizes
magick -background none fueki-logo-simplified.svg -resize 120x120 fueki-icon-60@2x.png
magick -background none fueki-logo-simplified.svg -resize 87x87 fueki-icon-29@3x.png
magick -background none fueki-logo-simplified.svg -resize 80x80 fueki-icon-40@2x.png

# Flatten 1024px icon (remove alpha channel)
magick fueki-icon-1024.png -background "#0F172A" -alpha remove -alpha off fueki-icon-1024.png
```

**Method B: Using Node.js (sharp library)**
```bash
npm install sharp

node scripts/generate-icons.js
```

**Method C: Online Tools**
- Upload SVG to: https://svgtopng.com/ or https://cloudconvert.com/svg-to-png
- Generate all required sizes
- Download and organize in AppIcon.appiconset/

### Step 2: Organize Files

Create this directory structure:
```
UnstoppableWallet/UnstoppableWallet/
├── AppIcon.xcassets/
│   └── AppIcon.appiconset/
│       ├── fueki-icon-20@2x.png (40×40)
│       ├── fueki-icon-20@3x.png (60×60)
│       ├── fueki-icon-29@2x.png (58×58)
│       ├── fueki-icon-29@3x.png (87×87)
│       ├── fueki-icon-40@2x.png (80×80)
│       ├── fueki-icon-40@3x.png (120×120)
│       ├── fueki-icon-60@2x.png (120×120)
│       ├── fueki-icon-60@3x.png (180×180)
│       ├── fueki-icon-ipad-20.png (20×20)
│       ├── fueki-icon-ipad-20@2x.png (40×40)
│       ├── fueki-icon-ipad-29.png (29×29)
│       ├── fueki-icon-ipad-29@2x.png (58×58)
│       ├── fueki-icon-ipad-40.png (40×40)
│       ├── fueki-icon-ipad-40@2x.png (80×80)
│       ├── fueki-icon-ipad-76.png (76×76)
│       ├── fueki-icon-ipad-76@2x.png (152×152)
│       ├── fueki-icon-ipad-83.5@2x.png (167×167)
│       ├── fueki-icon-1024.png (1024×1024)
│       └── Contents.json
│
├── AppIconAlternate.xcassets/
│   └── AppIcon.appiconset/
│       └── [Same files using fueki-logo-alternate.svg]
│
└── AppIconDev.xcassets/
    └── AppIcon.appiconset/
        └── [Same files with "DEV" badge overlay]
```

### Step 3: Update Contents.json

Replace the contents of `AppIcon.appiconset/Contents.json` with the complete configuration (see separate file).

---

## 🎨 Design Elements Explained

### Octopus Body
- **Shape**: Ellipse (140×160px radius at 1024×1024 scale)
- **Fill**: Linear gradient #2563EB → #3B82F6
- **Position**: Centered horizontally, slightly above center vertically
- **Effect**: Subtle shadow (0px, 4px, 12px blur, 30% opacity)

### Eyes
- **Outer Circle**: 18px radius, white (#FFFFFF), 90% opacity
- **Pupil**: 10px radius, deep slate (#0F172A)
- **Highlight**: 4px radius, white, 80% opacity (top-left of pupil)
- **Spacing**: 90px apart (center to center)
- **Expression**: Intelligent, trustworthy, forward-facing

### Tentacles
- **Count**: 8 (representing multi-chain support)
- **Style**: Smooth curved paths (SVG quadratic/cubic Bézier)
- **Stroke**: 24-32px width (thicker at base, thinner at tips)
- **Cap**: Round (stroke-linecap: round)
- **Gradient**: Same as body
- **Arrangement**: Symmetrical, flowing outward and downward

### Suction Cups
- **Size**: 8-12px radius
- **Color**: Accent blue (#3B82F6)
- **Opacity**: 60%
- **Placement**: Along tentacles at natural intervals
- **Purpose**: Add texture and biological realism

### Background
- **Primary**: Deep slate (#0F172A) solid
- **Alternate**: Light gradient (#F8FAFC → #E2E8F0)
- **Shape**: Rectangle with 180px corner radius (iOS handles actual rounding)
- **Glow**: Subtle radial gradient behind octopus (8px blur, 8% opacity)

---

## ✅ Quality Checklist

Before finalizing icons, verify:

- [ ] All 20+ PNG sizes generated correctly
- [ ] 1024×1024 icon has NO alpha channel (fully opaque)
- [ ] Colors match brand palette exactly
- [ ] Icons are recognizable at 60×60px (smallest size)
- [ ] Eyes are visible and expressive at all sizes
- [ ] Tentacles don't blur together at small sizes
- [ ] High contrast on both light and dark backgrounds
- [ ] Proper 15% padding from edges
- [ ] Files are optimized (compressed but high quality)
- [ ] Contents.json references all files correctly
- [ ] No copyright/trademark violations
- [ ] sRGB color space used throughout
- [ ] All files named consistently

---

## 🚀 Installation & Testing

### Install New Icons
```bash
# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Open project in Xcode
open UnstoppableWallet.xcodeproj

# Build and run on simulator
# Check app icon in:
# - Home screen
# - Settings app
# - App switcher
# - Notification banner
```

### Test Checklist
- [ ] Icon displays correctly on iPhone (all sizes)
- [ ] Icon displays correctly on iPad (all sizes)
- [ ] No pixelation or artifacts
- [ ] Colors render accurately
- [ ] Alternate icon works (if implemented)
- [ ] Watch icon displays (if applicable)
- [ ] App Store icon passes validation

---

## 📊 Design Rationale

### Why an Octopus?

1. **Multi-Chain Support**: 8 tentacles = 8+ blockchain networks
2. **Intelligence**: Octopi are known for problem-solving (smart contract interactions)
3. **Adaptability**: Changes color/shape (multi-asset wallet flexibility)
4. **Security**: Strong grip (asset protection)
5. **Unique**: Not overused in crypto (unlike lions, bulls, rockets)
6. **Professional**: Can be styled geometrically (not childish)

### Why This Color Scheme?

1. **Blue**: Universal color of trust and finance (banks, PayPal, Coinbase)
2. **Gradient**: Modern, tech-forward, depth without complexity
3. **Dark Background**: Premium feel, crypto-native aesthetic
4. **High Contrast**: Accessibility and visibility

### Why This Style?

1. **Geometric**: Professional, not cartoony
2. **Minimal Detail**: Scales well to small sizes
3. **Flowing Lines**: Suggests smooth transactions
4. **Symmetrical**: Balanced, trustworthy
5. **No Text**: Universal, language-agnostic

---

## 🔄 Future Variations

### Potential Badge Overlays
- **Beta**: Yellow "BETA" ribbon (AppIconDev)
- **Pro**: Gold crown or shield
- **Anniversary**: Special limited editions

### Animated Versions
- Launch animation: Tentacles extend outward
- Loading: Tentacles pulse/wave
- Success: Eyes blink, tentacles curl

### Brand Extensions
- **Favicon**: Simplified octopus head only
- **Logo Lockup**: "FUEKI" text + octopus icon
- **Merchandise**: T-shirts, stickers, physical wallet designs

---

## 📞 Support & Updates

**Design Files Location**: `/docs/fueki-logo-*.svg`
**Asset Catalogs**: `/UnstoppableWallet/UnstoppableWallet/*Icon.xcassets/`

**Version**: 1.0.0
**Last Updated**: October 2025
**Designer**: Claude Code Agent
**License**: Proprietary - Fueki Wallet

---

## 🎓 References

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/app-icons
- App Icon Sizes: https://developer.apple.com/design/human-interface-guidelines/app-icons#App-icon-sizes
- Color Theory for Finance Apps: Trust, security, professionalism
- Crypto Industry Standards: Coinbase, Kraken, MetaMask icon analysis

---

**End of Specification**

This logo represents Fueki Wallet's commitment to:
- Multi-chain asset management
- Professional-grade security
- Intelligent user experience
- Modern, trustworthy design
