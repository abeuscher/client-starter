const pug = require("pug");

const fs = require("fs");

const buildTemplates = (siteSettings) => {
  //Write templates
  fs.readdir(siteSettings.templates[0].srcDir, (err, files) => {
    if (err) {
      console.error("Could not list the directory.", err);
      process.exit(1);
    }
    files.forEach((file) => {
      if (file.indexOf(".pug") > -1) {
        const newFile = (siteSettings.templates[0].buildDir + file).replace(".pug", ".php");
        console.log("Writing template " + newFile);
        fs.writeFile(
          newFile,
          pug.renderFile(siteSettings.templates[0].srcDir + file, siteSettings.pugSettings, {
            siteurl: "/",
          }),
          (err) => {
            if (err) {
              console.error(err);
            }
          },
        );
      }
    });
  });
};
module.exports = buildTemplates;
