const esbuild = require("esbuild");
const pug = require("pug");
const path = require("path");
const fs = require("fs");

const pluginPug = () => ({
  name: "pug",
  setup(build) {
    build.onLoad({ filter: /\.(jade|pug)$/ }, async (args) => {
      // Read the Pug template file
      const template = await fs.promises.readFile(args.path, "utf8");

      // Compile the Pug template into a client-side JS function
      const compiledFunction = pug.compileClient(template, {
        filename: args.path,
        inlineRuntimeFunctions: false,
        compileDebug: false,
      });

      // Return the function as a module that can be imported
      const contents = `
        const pug = require('pug-runtime');
        module.exports = ${compiledFunction};
      `;

      return { contents, loader: "js" };
    });
  },
});

const buildScripts = (siteSettings) => {
  console.log("Building script files");

  // Ensure the output directory exists
  const outputDir = path.dirname(
    path.join(siteSettings.jsFiles[0].buildDir, siteSettings.jsFiles[0].buildFileName),
  );
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Build main app.js
  const mainJsFile = siteSettings.jsFiles[0];
  const mainEntryPoint = path.join(mainJsFile.srcDir, mainJsFile.srcFileName);
  const mainOutfile = path.join(mainJsFile.buildDir, mainJsFile.buildFileName);

  console.log(`Building main script: ${mainOutfile}`);
  const mainBuild = esbuild.build({
    entryPoints: [mainEntryPoint],
    bundle: true,
    minify: true,
    outfile: mainOutfile,
    platform: "browser",
    plugins: [pluginPug()],
  });

  // Wait for both builds to complete
  Promise.all([mainBuild])
    .then(() => {
      console.log(`Scripts built successfully.`);
      console.log(`Main output: ${mainOutfile}`);
    })
    .catch((error) => {
      console.error("Error during script build:", error);
    });
};

module.exports = buildScripts;
