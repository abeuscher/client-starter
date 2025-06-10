const sass = require("sass");
const fs = require("fs");
const path = require("path");

const buildStyles = (siteSettings) => {
  console.log("Writing css files");

  const srcDir = siteSettings.stylesheets[0].srcDir;
  const buildDir = siteSettings.stylesheets[0].buildDir;

  // Read the source directory
  fs.readdir(srcDir, (err, files) => {
    if (err) {
      console.error("Error reading source directory:", err);
      return;
    }

    // Filter for SCSS files that don't start with underscore
    const scssFiles = files.filter((file) => {
      return file.endsWith(".scss") && !file.startsWith("_");
    });

    if (scssFiles.length === 0) {
      console.log("No SCSS files found to compile");
      return;
    }

    // Compile each SCSS file
    scssFiles.forEach((file) => {
      try {
        const inputPath = path.join(srcDir, file);
        const outputFileName = file.replace(".scss", ".css");
        const outputPath = path.join(buildDir, outputFileName);

        console.log(`Compiling ${file} -> ${outputFileName}`);

        const fileData = sass.compile(inputPath, {
          style: "compressed",
          quietDeps: true,
        });

        fs.writeFile(outputPath, fileData.css, (writeErr) => {
          if (writeErr) {
            console.error(`Error writing ${outputFileName}:`, writeErr);
          } else {
            console.log(`Successfully compiled ${outputFileName}`);
          }
        });
      } catch (compileErr) {
        console.error(`Error compiling ${file}:`, compileErr);
      }
    });
  });
};

module.exports = buildStyles;
