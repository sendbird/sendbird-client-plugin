// Print the deprecated Sendbird APIs a JS/TS project uses, one per line:
//   DEPRECATED: <file>:<line>: '<name>' is deprecated. — <text of the declaration's @deprecated tag>
// Used by tools/local-sdk/deprecated-usage.sh (the upgrade-sdk skill) and by tests/e2e/build-fixture.sh.
// tsc does not report deprecations; the language service does, as suggestion diagnostics
// 6385 and 6387 with the declaration attached as related information. Only declarations from a
// Sendbird package (@sendbird/*, sendbird-*) count; app code and other libraries are ignored.
// Usage: TS_MODULE=<path to typescript> node js-deprecations.cjs <project-dir>
const path = require('path');
const ts = require(process.env.TS_MODULE || 'typescript');
const dir = path.resolve(process.argv[2] || '.');
const cfgPath = ts.findConfigFile(dir, ts.sys.fileExists, 'tsconfig.json');
let options = { allowJs: true, jsx: ts.JsxEmit.ReactJSX, moduleResolution: ts.ModuleResolutionKind.Bundler, module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 };
let files = [];
if (cfgPath) {
  const cfg = ts.readConfigFile(cfgPath, ts.sys.readFile);
  const parsed = ts.parseJsonConfigFileContent(cfg.config, ts.sys, path.dirname(cfgPath));
  options = parsed.options; files = parsed.fileNames;
} else {
  files = ts.sys.readDirectory(dir, ['.ts', '.tsx', '.js', '.jsx'], ['node_modules']);
}
files = files.filter((f) => !/[\\/]node_modules[\\/]/.test(f) && !f.endsWith('.d.ts'));
const host = {
  getScriptFileNames: () => files,
  getScriptVersion: () => '1',
  getScriptSnapshot: (f) => (ts.sys.fileExists(f) ? ts.ScriptSnapshot.fromString(ts.sys.readFile(f)) : undefined),
  getCurrentDirectory: () => dir,
  getCompilationSettings: () => options,
  getDefaultLibFileName: (o) => ts.getDefaultLibFilePath(o),
  fileExists: ts.sys.fileExists, readFile: ts.sys.readFile, readDirectory: ts.sys.readDirectory,
  directoryExists: ts.sys.directoryExists, getDirectories: ts.sys.getDirectories,
};
const service = ts.createLanguageService(host, ts.createDocumentRegistry());
const sendbird = /(^|[\\/])(@sendbird[\\/]|sendbird-[a-z]+[\\/])/;
const out = new Set();
for (const f of files) {
  for (const d of service.getSuggestionDiagnostics(f)) {
    if (d.code !== 6385 && d.code !== 6387) continue;
    const decls = (d.relatedInformation || []).filter((r) => r.file);
    // test the path relative to the project: a checkout under a folder such as sendbird-plugin/
    // would otherwise mark the app's own declarations as Sendbird ones
    if (!decls.some((r) => sendbird.test(path.relative(dir, r.file.fileName)))) continue;
    const { line } = d.file.getLineAndCharacterOfPosition(d.start);
    // the SDK's own words: the @deprecated tag in the doc comment right above the declaration
    const decl = decls.find((r) => sendbird.test(path.relative(dir, r.file.fileName)));
    // (the related information points at the tag itself, or at the declaration under the comment)
    const text = decl.file.text;
    const open = text.lastIndexOf('/**', decl.start);
    const tag = open >= 0 ? /@deprecated\b[ \t]*([^\n*]*)/.exec(text.slice(open, decl.start + 400)) : null;
    const why = tag && tag[1].trim() ? ` — ${tag[1].trim()}` : '';
    out.add(`DEPRECATED: ${path.relative(dir, f)}:${line + 1}: ${ts.flattenDiagnosticMessageText(d.messageText, ' ')}${why}`);
  }
}
[...out].sort().forEach((l) => console.log(l));
