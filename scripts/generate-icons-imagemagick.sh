#!/bin/bash

###############################################################################
# Fueki Icon Generator (ImageMagick version)
# Converts SVG logos to all required iOS PNG sizes
#
# Requirements:
#   brew install imagemagick
#
# Usage:
#   bash scripts/generate-icons-imagemagick.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🐙 Fueki Icon Generator (ImageMagick)"
echo "======================================================"

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo -e "${RED}❌ Error: ImageMagick not found${NC}"
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."
DOCS_DIR="$PROJECT_DIR/docs"
OUTPUT_DIR="$PROJECT_DIR/UnstoppableWallet/UnstoppableWallet"

# Source files
PRIMARY_SVG="$DOCS_DIR/fueki-logo-design.svg"
SIMPLIFIED_SVG="$DOCS_DIR/fueki-logo-simplified.svg"
ALTERNATE_SVG="$DOCS_DIR/fueki-logo-alternate.svg"

# Check if source files exist
if [ ! -f "$PRIMARY_SVG" ]; then
    echo -e "${RED}❌ Error: Source SVG not found: $PRIMARY_SVG${NC}"
    exit 1
fi

# Function to generate icon
generate_icon() {
    local source="$1"
    local output="$2"
    local size="$3"
    local flatten="${4:-false}"

    echo -e "${BLUE}Generating $(basename "$output") (${size}×${size}px)...${NC}"

    if [ "$flatten" = true ]; then
        # Flatten for App Store icon (remove alpha)
        magick "$source" \
            -resize "${size}x${size}" \
            -background "#0F172A" \
            -alpha remove \
            -alpha off \
            "$output"
    else
        # Normal icon with transparency
        magick "$source" \
            -resize "${size}x${size}" \
            "$output"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Generated $(basename "$output")${NC}"
    else
        echo -e "${RED}✗ Failed to generate $(basename "$output")${NC}"
        return 1
    fi
}

# Function to generate all sizes for one icon set
generate_icon_set() {
    local source_primary="$1"
    local source_simplified="$2"
    local output_dir="$3"
    local set_name="$4"

    echo -e "\n${YELLOW}📱 Generating $set_name...${NC}"

    # Create output directory
    mkdir -p "$output_dir"

    # iPhone icons
    generate_icon "$source_primary" "$output_dir/fueki-icon-20@2x.png" 40
    generate_icon "$source_primary" "$output_dir/fueki-icon-20@3x.png" 60
    generate_icon "$source_primary" "$output_dir/fueki-icon-29@2x.png" 58
    generate_icon "$source_primary" "$output_dir/fueki-icon-29@3x.png" 87
    generate_icon "$source_primary" "$output_dir/fueki-icon-40@2x.png" 80
    generate_icon "$source_primary" "$output_dir/fueki-icon-40@3x.png" 120
    generate_icon "$source_simplified" "$output_dir/fueki-icon-60@2x.png" 120  # Use simplified
    generate_icon "$source_primary" "$output_dir/fueki-icon-60@3x.png" 180

    # iPad icons
    generate_icon "$source_simplified" "$output_dir/fueki-icon-ipad-20.png" 20
    generate_icon "$source_primary" "$output_dir/fueki-icon-ipad-20@2x.png" 40
    generate_icon "$source_simplified" "$output_dir/fueki-icon-ipad-29.png" 29
    generate_icon "$source_simplified" "$output_dir/fueki-icon-ipad-29@2x.png" 58
    generate_icon "$source_simplified" "$output_dir/fueki-icon-ipad-40.png" 40
    generate_icon "$source_simplified" "$output_dir/fueki-icon-ipad-40@2x.png" 80
    generate_icon "$source_primary" "$output_dir/fueki-icon-ipad-76.png" 76
    generate_icon "$source_primary" "$output_dir/fueki-icon-ipad-76@2x.png" 152
    generate_icon "$source_primary" "$output_dir/fueki-icon-ipad-83.5@2x.png" 167

    # App Store icon (flattened, no alpha)
    generate_icon "$source_primary" "$output_dir/fueki-icon-1024.png" 1024 true

    # Generate Contents.json
    cat > "$output_dir/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "fueki-icon-20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "fueki-icon-20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "fueki-icon-29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "fueki-icon-29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "fueki-icon-40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "fueki-icon-40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "fueki-icon-60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "fueki-icon-60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "fueki-icon-ipad-20.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "fueki-icon-ipad-20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "fueki-icon-ipad-29.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "fueki-icon-ipad-29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "fueki-icon-ipad-40.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "fueki-icon-ipad-40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "fueki-icon-ipad-76.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "fueki-icon-ipad-76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "fueki-icon-ipad-83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "fueki-icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    echo -e "${GREEN}✓ Generated Contents.json${NC}"
}

# Generate primary icon set
generate_icon_set \
    "$PRIMARY_SVG" \
    "$SIMPLIFIED_SVG" \
    "$OUTPUT_DIR/AppIcon.xcassets/AppIcon.appiconset" \
    "Primary App Icons"

# Generate alternate icon set
generate_icon_set \
    "$ALTERNATE_SVG" \
    "$SIMPLIFIED_SVG" \
    "$OUTPUT_DIR/AppIconAlternate.xcassets/AppIcon.appiconset" \
    "Alternate App Icons"

# Generate dev icon set (same as primary for now)
generate_icon_set \
    "$PRIMARY_SVG" \
    "$SIMPLIFIED_SVG" \
    "$OUTPUT_DIR/AppIconDev.xcassets/AppIcon.appiconset" \
    "Dev App Icons"

echo -e "\n${GREEN}✅ Icon generation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Open Xcode and verify icons in asset catalogs"
echo "2. Clean derived data: rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "3. Build and test on simulator"
echo "4. Check icons in Settings, home screen, and notifications"
echo "5. Submit to App Store Connect"
echo ""
echo -e "${BLUE}Icon locations:${NC}"
echo "  - Primary: UnstoppableWallet/UnstoppableWallet/AppIcon.xcassets/"
echo "  - Alternate: UnstoppableWallet/UnstoppableWallet/AppIconAlternate.xcassets/"
echo "  - Dev: UnstoppableWallet/UnstoppableWallet/AppIconDev.xcassets/"
