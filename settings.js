const pugPHPFilter = require("pug-php-filter");

var srcDir = "./src/";
var buildDir = "./public_html/wp-content/themes/${CLIENT_NAME}/";

var jsSrcDir = srcDir + "js/";
var jsBuildDir = buildDir + "js/";

var sassSrcDir = srcDir + "scss/";
var sassBuildDir = buildDir;

var assetsSrcDir = srcDir + "public_transfer/";
var assetsBuildDir = buildDir;

var templateSrcDir = srcDir + "templates/";
var templateBuildDir = buildDir;

function siteSettings() {
  return {
    siteName: "${WP_TITLE}",
    pugSettings: {
      filters: {
        php: pugPHPFilter,
      },
    },
    siteThumb: "screenshot.png",
    directories: [buildDir, jsBuildDir],
    srcDir: srcDir,
    jsFiles: [
      {
        name: "Main Bundle",
        srcDir: jsSrcDir,
        srcFileName: "app.js",
        buildDir: jsBuildDir,
        buildFileName: "bundle.min.js",
      },
    ],
    templates: [
      {
        name: "Main Template Group",
        srcDir: templateSrcDir,
        buildDir: templateBuildDir,
      },
    ],
    stylesheets: [
      {
        name: "Main Stylesheet",
        srcDir: sassSrcDir,
        buildDir: sassBuildDir,
      }
    ],
    assets: [
      {
        name: "Main Public Assets",
        srcDir: assetsSrcDir,
        buildDir: assetsBuildDir,
      },
    ],
  };
}
module.exports = siteSettings;