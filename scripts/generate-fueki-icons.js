#!/usr/bin/env node

/**
 * Fueki Icon Generator
 * Converts SVG logos to all required iOS PNG sizes
 *
 * Requirements:
 *   npm install sharp
 *
 * Usage:
 *   node scripts/generate-fueki-icons.js
 */

const fs = require('fs').promises;
const path = require('path');
const sharp = require('sharp');

// Configuration
const config = {
  sourceDir: path.join(__dirname, '..', 'docs'),
  outputDir: path.join(__dirname, '..', 'UnstoppableWallet', 'UnstoppableWallet'),

  icons: {
    primary: {
      source: 'fueki-logo-design.svg',
      output: 'AppIcon.xcassets/AppIcon.appiconset'
    },
    alternate: {
      source: 'fueki-logo-alternate.svg',
      output: 'AppIconAlternate.xcassets/AppIcon.appiconset'
    },
    dev: {
      source: 'fueki-logo-design.svg',
      output: 'AppIconDev.xcassets/AppIcon.appiconset',
      badge: true
    }
  }
};

// All required iOS icon sizes
const iconSizes = [
  // iPhone
  { name: 'fueki-icon-20@2x.png', size: 40, idiom: 'iphone', scale: '2x', sizeStr: '20x20' },
  { name: 'fueki-icon-20@3x.png', size: 60, idiom: 'iphone', scale: '3x', sizeStr: '20x20' },
  { name: 'fueki-icon-29@2x.png', size: 58, idiom: 'iphone', scale: '2x', sizeStr: '29x29' },
  { name: 'fueki-icon-29@3x.png', size: 87, idiom: 'iphone', scale: '3x', sizeStr: '29x29' },
  { name: 'fueki-icon-40@2x.png', size: 80, idiom: 'iphone', scale: '2x', sizeStr: '40x40' },
  { name: 'fueki-icon-40@3x.png', size: 120, idiom: 'iphone', scale: '3x', sizeStr: '40x40' },
  { name: 'fueki-icon-60@2x.png', size: 120, idiom: 'iphone', scale: '2x', sizeStr: '60x60', useSimplified: true },
  { name: 'fueki-icon-60@3x.png', size: 180, idiom: 'iphone', scale: '3x', sizeStr: '60x60' },

  // iPad
  { name: 'fueki-icon-ipad-20.png', size: 20, idiom: 'ipad', scale: '1x', sizeStr: '20x20', useSimplified: true },
  { name: 'fueki-icon-ipad-20@2x.png', size: 40, idiom: 'ipad', scale: '2x', sizeStr: '20x20' },
  { name: 'fueki-icon-ipad-29.png', size: 29, idiom: 'ipad', scale: '1x', sizeStr: '29x29', useSimplified: true },
  { name: 'fueki-icon-ipad-29@2x.png', size: 58, idiom: 'ipad', scale: '2x', sizeStr: '29x29', useSimplified: true },
  { name: 'fueki-icon-ipad-40.png', size: 40, idiom: 'ipad', scale: '1x', sizeStr: '40x40', useSimplified: true },
  { name: 'fueki-icon-ipad-40@2x.png', size: 80, idiom: 'ipad', scale: '2x', sizeStr: '40x40', useSimplified: true },
  { name: 'fueki-icon-ipad-76.png', size: 76, idiom: 'ipad', scale: '1x', sizeStr: '76x76' },
  { name: 'fueki-icon-ipad-76@2x.png', size: 152, idiom: 'ipad', scale: '2x', sizeStr: '76x76' },
  { name: 'fueki-icon-ipad-83.5@2x.png', size: 167, idiom: 'ipad', scale: '2x', sizeStr: '83.5x83.5' },

  // App Store
  { name: 'fueki-icon-1024.png', size: 1024, idiom: 'ios-marketing', scale: '1x', sizeStr: '1024x1024', flatten: true },
];

/**
 * Generate a single PNG icon from SVG source
 */
async function generateIcon(sourcePath, outputPath, size, options = {}) {
  try {
    console.log(`Generating ${path.basename(outputPath)} (${size}×${size}px)...`);

    let image = sharp(sourcePath, { density: 300 });

    // Resize to target size
    image = image.resize(size, size, {
      fit: 'contain',
      background: { r: 15, g: 23, b: 42, alpha: 1 } // #0F172A
    });

    // Flatten for App Store icon (remove alpha channel)
    if (options.flatten) {
      image = image.flatten({ background: { r: 15, g: 23, b: 42 } });
    }

    // Add DEV badge if needed
    if (options.badge) {
      // TODO: Add "DEV" text overlay
      // This would require SVG compositing or text rendering
    }

    // Output PNG
    await image.png({ compressionLevel: 9, quality: 100 }).toFile(outputPath);

    console.log(`✓ Generated ${path.basename(outputPath)}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to generate ${path.basename(outputPath)}:`, error.message);
    return false;
  }
}

/**
 * Generate Contents.json for asset catalog
 */
function generateContentsJson(iconSet) {
  const images = iconSet.map(icon => ({
    filename: icon.name,
    idiom: icon.idiom,
    scale: icon.scale,
    size: icon.sizeStr
  }));

  return JSON.stringify({
    images,
    info: {
      author: 'xcode',
      version: 1
    }
  }, null, 2);
}

/**
 * Main execution
 */
async function main() {
  console.log('🐙 Fueki Icon Generator');
  console.log('=' .repeat(50));

  try {
    // Generate primary icons
    console.log('\n📱 Generating Primary App Icons...');
    const primarySource = path.join(config.sourceDir, config.icons.primary.source);
    const primarySimplified = path.join(config.sourceDir, 'fueki-logo-simplified.svg');
    const primaryOutput = path.join(config.outputDir, config.icons.primary.output);

    // Ensure output directory exists
    await fs.mkdir(primaryOutput, { recursive: true });

    // Generate all sizes
    for (const icon of iconSizes) {
      const sourcePath = icon.useSimplified ? primarySimplified : primarySource;
      const outputPath = path.join(primaryOutput, icon.name);
      await generateIcon(sourcePath, outputPath, icon.size, { flatten: icon.flatten });
    }

    // Generate Contents.json
    const contentsPath = path.join(primaryOutput, 'Contents.json');
    const contentsJson = generateContentsJson(iconSizes);
    await fs.writeFile(contentsPath, contentsJson, 'utf8');
    console.log(`✓ Generated Contents.json`);

    // Generate alternate icons
    console.log('\n🌙 Generating Alternate App Icons...');
    const alternateSource = path.join(config.sourceDir, config.icons.alternate.source);
    const alternateOutput = path.join(config.outputDir, config.icons.alternate.output);

    await fs.mkdir(alternateOutput, { recursive: true });

    for (const icon of iconSizes) {
      const outputPath = path.join(alternateOutput, icon.name);
      await generateIcon(alternateSource, outputPath, icon.size, { flatten: icon.flatten });
    }

    const alternateContentsPath = path.join(alternateOutput, 'Contents.json');
    await fs.writeFile(alternateContentsPath, contentsJson, 'utf8');
    console.log(`✓ Generated Contents.json for alternate`);

    console.log('\n✅ Icon generation complete!');
    console.log('\nNext steps:');
    console.log('1. Open Xcode and verify icons in asset catalogs');
    console.log('2. Clean derived data: rm -rf ~/Library/Developer/Xcode/DerivedData');
    console.log('3. Build and test on simulator');
    console.log('4. Check icons in Settings, home screen, and App Store Connect');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

module.exports = { generateIcon, generateContentsJson };
