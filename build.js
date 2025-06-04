const chokidar = require("chokidar");
const fs = require("fs");
const fse = require("fs-extra");
const path = require("path");

const siteSettings = require("./settings.js")();

const buildTemplates = require("./build/buildTemplates.js");
const buildScripts = require("./build/buildScripts.js");
const buildStyles = require("./build/buildStyles.js");

// Parse command line arguments
const args = process.argv.slice(2);
const isProduction = args.includes("--production") || args.includes("--silent");
const isSilent = args.includes("--silent") || isProduction;
const isWatch = args.includes("--watch") && !isProduction;

// Logging function that respects silent mode
const log = (message) => {
  if (!isSilent) {
    console.log(message);
  }
};

const logError = (message) => {
  // Always log errors, even in silent mode
  console.error(message);
};

const clearDir = (directory, cb) => {
  if (fs.existsSync(directory)) {
    fs.rmSync(directory, { recursive: true, force: true });
    log("Directory cleared:", directory);
  }
  fs.mkdir(path.join(directory), { recursive: true }, (err) => {
    if (err) {
      return logError("Error creating directory:", err);
    }
    log("Directory created:", directory);
    if (cb) {
      cb();
    }
  });
};

const buildSite = () => {
  try {
    // Ensure all build directories exist
    siteSettings.directories.forEach((dir) => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });

    // Build templates first to ensure they are available for scripts and styles
    buildTemplates(siteSettings);
    log("Templates built successfully.");

    // Build scripts next
    buildScripts(siteSettings);
    log("Scripts built successfully.");

    // Finally, build styles
    buildStyles(siteSettings);
    log("Styles built successfully.");

    // Copy assets
    siteSettings.assets.forEach((asset) => {
      const srcPath = path.resolve(asset.srcDir);
      if (fs.existsSync(srcPath)) {
        fse.copySync(srcPath, asset.buildDir, { overwrite: true });
        log(`Assets copied from ${srcPath} to ${asset.buildDir}`);
      } else {
        console.warn(`Asset source directory not found: ${srcPath}`);
      }
    });

    if (siteSettings.siteThumb) {
      const thumbSrc = path.join(siteSettings.srcDir, siteSettings.siteThumb);
      const thumbDest = path.join(siteSettings.assets[0].buildDir, siteSettings.siteThumb);
      if (fs.existsSync(thumbSrc)) {
        fse.copyFileSync(thumbSrc, thumbDest);
        log(`Site thumbnail copied to ${thumbDest}`);
      } else {
        console.warn(`Site thumbnail not found: ${thumbSrc}`);
      }
    }

    log("Build process completed successfully.");

    // Exit in production/silent mode after successful build
    if (isProduction) {
      process.exit(0);
    }
  } catch (err) {
    logError("Error during build process:", err);
    process.exit(1);
  }
};

// Clear template directory and start build process
clearDir(siteSettings.templates[0].buildDir, () => {
  buildSite();

  // Only set up watchers if not in production mode
  if (!isProduction && (isWatch || !args.length)) {
    log("Setting up file watchers for development...");

    // Set up file watchers for continuous development
    const templateWatcher = chokidar.watch(siteSettings.templates[0].srcDir);
    templateWatcher.on("change", () => {
      log("Template change detected.");
      buildTemplates(siteSettings);
    });

    const scriptWatcher = chokidar.watch(siteSettings.jsFiles[0].srcDir);
    scriptWatcher.on("change", () => {
      log("Script change detected.");
      buildScripts(siteSettings);
    });

    const stylesheetWatcher = chokidar.watch(siteSettings.stylesheets[0].srcDir);
    stylesheetWatcher.on("change", () => {
      log("Stylesheet change detected.");
      buildStyles(siteSettings);
    });

    log("File watchers active. Press Ctrl+C to stop.");
  }
});
