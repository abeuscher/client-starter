const sass = require("sass");
const fs = require("fs");

const buildStyles = (siteSettings) => {
  console.log("Writing css file");
  const fileData = sass.compile(siteSettings.stylesheets[0].srcDir + "style.scss", {
    style: "compressed",
    quietDeps: true,
  });
  fs.writeFile(siteSettings.stylesheets[0].buildDir + "style.css", fileData.css, (err) => {
    if (err) {
      console.error(err);
    }
  });
};

module.exports = buildStyles;
