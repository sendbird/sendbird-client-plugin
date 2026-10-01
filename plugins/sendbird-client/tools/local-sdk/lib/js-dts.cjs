#!/usr/bin/env node
// Read the public API surface of a customer-INSTALLED npm package from its shipped .d.ts
// entry points, using the TypeScript compiler API.
//
// Why the compiler and not grep: Sendbird entry files mostly re-export other files
// (`export * from './x'`, `export { A } from './y'`), classes inherit members, and
// namespaces merge with classes. A line grep over the entry file finds none of that —
// on @sendbird/chat 4.22.13 and @sendbird/uikit-react 3.19.1 it returned 0 lines.
//
// Usage: node js-dts.cjs <package-dir | file.d.ts> <title> [project-dir]
// Emits markdown to stdout (read-dts.sh adds the local-read header). Only exported
// declarations are emitted; private/protected/#private/_-prefixed members and every
// comment are dropped before output.
//
// `typescript` is resolved from the customer project first (most JS/TS projects have
// it), then from the package, then from NODE_PATH. Exit 5 when it is not found, so the
// caller can fall back. Dependencies' declarations resolve through the project's
// node_modules; an export, `export *` or base type that does not resolve is listed
// under "Unresolved references" and counted on stderr — nothing is dropped silently.
'use strict';
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const [input, title, projectDir] = process.argv.slice(2);
if (!input || !title) { console.error('usage: js-dts.cjs <package-dir | file.d.ts> <title> [project-dir]'); process.exit(2); }
const singleFile = /\.d\.(c|m)?ts$/.test(input) && fs.statSync(input).isFile();
const pkgDir = singleFile ? path.dirname(input) : input;

function loadTypescript() {
  const bases = [projectDir, pkgDir].filter(Boolean).map((d) => path.join(path.resolve(d), 'package.json'));
  for (const b of bases) {
    try { return createRequire(b)('typescript'); } catch (_) { /* try the next base */ }
  }
  try { return require('typescript'); } catch (_) { return null; }
}
const ts = loadTypescript();
if (!ts) { console.error('typescript not found in the project, the package, or NODE_PATH'); process.exit(5); }

const pkgFile = path.join(pkgDir, 'package.json');
const pkg = !singleFile && fs.existsSync(pkgFile) ? JSON.parse(fs.readFileSync(pkgFile, 'utf8')) : { name: title };

// Subpaths we never treat as public even if a package exports them.
const EXCLUDED = /\/(tests?|__tests__|internal|dev-only|experimental|\.private)(\/|$)/i;

function typesOf(target) {
  if (!target) return null;
  if (typeof target === 'string') return target.endsWith('.d.ts') ? target : null;
  if (typeof target === 'object') {
    if (typeof target.types === 'string') return target.types;
    for (const k of ['import', 'require', 'default', 'node']) {
      const t = typesOf(target[k]);
      if (t) return t;
    }
  }
  return null;
}

// Collect (importPath -> .d.ts file) from package.json "exports", falling back to types/typings.
const entries = [];
if (singleFile) entries.push({ importPath: title, file: path.resolve(input) });
if (!singleFile && pkg.exports && typeof pkg.exports === 'object') {
  for (const [key, target] of Object.entries(pkg.exports)) {
    if (key.includes('*') || key === './package.json' || EXCLUDED.test(key)) continue;
    const t = typesOf(target);
    if (!t) continue;
    const file = path.resolve(pkgDir, t);
    if (!fs.existsSync(file)) continue;
    entries.push({ importPath: key === '.' ? pkg.name : `${pkg.name}/${key.replace(/^\.\//, '')}`, file });
  }
}
if (!singleFile && !entries.find((e) => e.importPath === pkg.name)) {
  const t = pkg.types || pkg.typings || 'index.d.ts';
  const file = path.resolve(pkgDir, t);
  if (fs.existsSync(file)) entries.unshift({ importPath: pkg.name, file });
}
if (entries.length === 0) { console.error(`no .d.ts entry points in ${pkgDir}`); process.exit(3); }

const program = ts.createProgram(entries.map((e) => e.file), {
  noEmit: true, skipLibCheck: true, allowJs: false, target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS, moduleResolution: ts.ModuleResolutionKind.Node10,
});
const checker = program.getTypeChecker();

const stripComments = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/[^\n]*/g, '$1');
const oneLine = (s) => stripComments(s).replace(/\s+/g, ' ').replace(/\s*;\s*$/, '').trim();
const clip = (s, n = 400) => (s.length > n ? `${s.slice(0, n)} …` : s);

const hasMod = (node, kind) => !!(ts.getCombinedModifierFlags(node) & kind);
function isPublicMember(m) {
  if (hasMod(m, ts.ModifierFlags.Private) || hasMod(m, ts.ModifierFlags.Protected)) return false;
  const n = m.name && ts.isIdentifier(m.name) ? m.name.text : m.name && m.name.getText ? m.name.getText() : '';
  if (m.name && ts.isPrivateIdentifier && ts.isPrivateIdentifier(m.name)) return false;
  if (n.startsWith('_')) return false;
  return true;
}

// symbolKey -> { kind, name, importPaths:Set, lines:[] }
const out = new Map();

// Interfaces whose members come mostly through `extends Pick<...>`, `Omit<...>`,
// `PartialRequired<...>` etc. show almost nothing from their own body, and the
// parent is often a mapped type with no section of its own. For those, list every
// property of the resolved type instead (own + inherited), with its checked type.
const computedTypes = new Set(); // display names that hold a compiler-computed property type
function resolvedInterfaceProps(target, d, display) {
  const lines = [];
  const t = checker.getDeclaredTypeOfSymbol(target);
  for (const p of checker.getPropertiesOfType(t)) {
    const name = p.getName();
    if (name.startsWith('_') || name.startsWith('#')) continue;
    const pd = (p.getDeclarations() || [])[0];
    if (pd && (hasMod(pd, ts.ModifierFlags.Private) || hasMod(pd, ts.ModifierFlags.Protected))) continue;
    const opt = p.flags & ts.SymbolFlags.Optional ? '?' : '';
    // Prefer the type as written in the declaring file: the checker prints a type it
    // cannot resolve (a missing @types package) as a wrong name such as `React`.
    if (pd && (ts.isPropertySignature(pd) || ts.isPropertyDeclaration(pd)) && pd.type) {
      lines.push(clip(oneLine(`${name}${opt}: ${pd.type.getText(pd.getSourceFile())}`)));
      continue;
    }
    if (pd && (ts.isMethodSignature(pd) || ts.isMethodDeclaration(pd))) {
      lines.push(clip(oneLine(pd.getText(pd.getSourceFile()))));
      continue;
    }
    const ty = checker.typeToString(checker.getTypeOfSymbolAtLocation(p, d), d);
    computedTypes.add(display);
    lines.push(clip(oneLine(`${name}${opt}: ${ty}`)));
  }
  return lines;
}

// References TypeScript could not resolve (a dependency that is not installed, or a
// broken path). They are reported, never silently dropped.
const unresolved = [];
const moduleOf = (sym) => {
  const spec = (sym.getDeclarations() || []).find(ts.isExportSpecifier);
  const ed = spec && spec.parent && spec.parent.parent;
  return ed && ed.moduleSpecifier && ts.isStringLiteral(ed.moduleSpecifier) ? ed.moduleSpecifier.text : null;
};
const unresolvedSeen = new Set();
function addUnresolved(u) {
  const k = `${u.what}|${u.ref}|${u.importPath}`;
  if (!unresolvedSeen.has(k)) { unresolvedSeen.add(k); unresolved.push(u); }
}
const nameNodeOf = (x) => (ts.isQualifiedName(x) ? x.right : ts.isPropertyAccessExpression(x) ? x.name : x);
const resolved = (node) => {
  const s0 = checker.getSymbolAtLocation(nameNodeOf(node));
  const r = s0 && s0.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(s0) : s0;
  return r && (r.getDeclarations() || []).length ? r : null;
};
// Every type name inside a heritage type, not only the outer one: `Pick<Missing, 'x'>`
// resolves `Pick` but not `Missing`.
function unresolvedNamesIn(node, sf) {
  const names = [];
  const visit = (n) => {
    const nameNode = ts.isTypeReferenceNode(n) ? n.typeName : ts.isExpressionWithTypeArguments(n) ? n.expression : null;
    if (nameNode && !resolved(nameNode)) names.push(nameNode.getText(sf));
    ts.forEachChild(n, visit);
  };
  visit(node);
  return names;
}
// Base types of a class/interface, and of every local base it inherits from: a resolved
// base whose own parent is missing still leaves the inherited members incomplete.
const incompleteBases = new Set(); // display names whose base types did not fully resolve
function unresolvedBases(d, sf, display, importPath, via = [], seen = new Set()) {
  if (seen.has(d)) return; seen.add(d);
  for (const h of d.heritageClauses || []) {
    for (const t of h.types) {
      for (const name of unresolvedNamesIn(t, sf)) {
        incompleteBases.add(display);
        const text = oneLine(t.getText(sf));
        addUnresolved({ what: `base type of ${display}`,
          ref: `${name}${text !== name ? ` in ${text}` : ''}${via.length ? ` (via ${via.join(' → ')})` : ''}`, importPath });
      }
      const base = resolved(t.expression);
      for (const bd of (base && base.getDeclarations()) || []) {
        if (ts.isInterfaceDeclaration(bd) || ts.isClassDeclaration(bd)) {
          unresolvedBases(bd, bd.getSourceFile(), display, importPath, [...via, base.getName()], seen);
        }
      }
    }
  }
}

// `export * from 'x'` whose module does not resolve adds no symbols at all. Follow star
// exports through every barrel file reachable from the entry, not just the entry itself.
function unresolvedStars(entrySf, importPath) {
  const seen = new Set(); const queue = [entrySf];
  while (queue.length) {
    const f = queue.shift();
    if (seen.has(f.fileName)) continue; seen.add(f.fileName);
    for (const st of f.statements) {
      if (!ts.isExportDeclaration(st) || st.exportClause || !st.moduleSpecifier || !ts.isStringLiteral(st.moduleSpecifier)) continue;
      const ms = checker.getSymbolAtLocation(st.moduleSpecifier);
      if (!ms) {
        const where = f === entrySf ? '' : ` (in ${path.basename(f.fileName)})`;
        addUnresolved({ what: 'export *', ref: `from '${st.moduleSpecifier.text}'${where}`, importPath });
        continue;
      }
      for (const md of ms.getDeclarations() || []) if (ts.isSourceFile(md)) queue.push(md);
    }
  }
}

// Declarations directly inside a namespace body (not a class's static members).
function inNamespaceBody(node) {
  for (let n = node.parent; n; n = n.parent) {
    if (ts.isModuleBlock(n)) return true;
    if (ts.isClassLike(n) || ts.isInterfaceDeclaration(n) || ts.isEnumDeclaration(n) || ts.isSourceFile(n)) return false;
  }
  return false;
}
// Lines for a namespace's value/type members; nested classes, interfaces, enums and
// namespaces are returned in `nested` so they get their own `Ns.Inner` section.
function namespaceMembers(target, display) {
  const lines = []; const nested = [];
  const members = [...(target.exports ? target.exports.values() : [])]
    .filter((m) => !m.getName().startsWith('_') && m.getName() !== 'prototype')
    .filter((m) => (m.getDeclarations() || []).some(inNamespaceBody))
    .sort((a, b) => a.getName().localeCompare(b.getName()));
  for (const m of members) {
    const md = (m.getDeclarations() || []).filter(inNamespaceBody);
    const first = md[0]; const msf = first.getSourceFile();
    if (md.some((x) => ts.isClassDeclaration(x) || ts.isInterfaceDeclaration(x) || ts.isEnumDeclaration(x) || ts.isModuleDeclaration(x))) {
      nested.push([m, `${display}.${m.getName()}`]);
    } else if (ts.isFunctionDeclaration(first)) {
      for (const fd of md.filter(ts.isFunctionDeclaration)) lines.push(clip(oneLine(fd.getText(msf))));
    } else if (ts.isVariableDeclaration(first)) {
      const kw = first.parent && first.parent.flags & ts.NodeFlags.Const ? 'const' : first.parent && first.parent.flags & ts.NodeFlags.Let ? 'let' : 'var';
      lines.push(clip(`${kw} ${oneLine(first.getText(msf))}`));
    } else if (ts.isTypeAliasDeclaration(first)) {
      lines.push(clip(oneLine(first.getText(msf)), 600));
    } else if (ts.isExportSpecifier(first) || ts.isImportEqualsDeclaration(first)) {
      lines.push(clip(oneLine(first.getText(msf))));
    }
  }
  return { lines, nested };
}

// Classes can extend a base class that no entry exports. Its public members are still
// callable on the subclass, so list them here; an exported base has its own section.
const exportedTargets = new Set();
function inheritedFromHiddenBases(d, seen = new Set()) {
  const lines = [];
  for (const h of d.heritageClauses || []) {
    if (h.token !== ts.SyntaxKind.ExtendsKeyword) continue;
    for (const t of h.types) {
      const base = resolved(t.expression);
      if (!base || seen.has(base)) continue; seen.add(base);
      const bd = (base.getDeclarations() || []).find(ts.isClassDeclaration);
      if (!bd) continue;
      if (!exportedTargets.has(base)) {
        const bsf = bd.getSourceFile();
        const own = bd.members.filter(isPublicMember).map((m) => clip(oneLine(m.getText(bsf))));
        if (own.length) { lines.push(`_inherited from ${base.getName()} (not exported):_`); lines.push(...own); }
      }
      lines.push(...inheritedFromHiddenBases(bd, seen));
    }
  }
  return lines;
}

function record(sym, importPath, displayName) {
  const target = sym.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(sym) : sym;
  const decls = target.getDeclarations() || [];
  if (decls.length === 0) {
    const from = moduleOf(sym);
    addUnresolved({ what: `export ${displayName || sym.getName()}`, ref: from ? `from '${from}'` : 'target has no declaration', importPath });
    return;
  }
  const d = decls[0];
  const sf = d.getSourceFile();
  // A default export is listed under its real declared name (e.g. `SendbirdChat`).
  let display = displayName || sym.getName();
  if (display === 'default') {
    display = target.getName() !== 'default' ? target.getName()
      : (d.name && d.name.getText ? d.name.getText(sf) : 'default');
    importPath = `${importPath} (default export)`;
  }
  const key = `${display}|${sf.fileName}|${d.pos}`;
  if (out.has(key)) { out.get(key).importPaths.add(importPath); return; }

  let kind; const lines = [];
  if (ts.isClassDeclaration(d)) {
    kind = hasMod(d, ts.ModifierFlags.Abstract) ? 'abstract class' : 'class';
    unresolvedBases(d, sf, display, importPath);
    const heritage = (d.heritageClauses || []).map((h) => oneLine(h.getText(sf))).join(' ');
    if (heritage) lines.push(`_${heritage}_`);
    for (const m of d.members) if (isPublicMember(m)) lines.push(clip(oneLine(m.getText(sf))));
    lines.push(...inheritedFromHiddenBases(d));
  } else if (ts.isInterfaceDeclaration(d)) {
    kind = 'interface';
    unresolvedBases(d, sf, display, importPath);
    const heritage = (d.heritageClauses || []).map((h) => oneLine(h.getText(sf))).join(' ');
    if (heritage) {
      lines.push(`_${heritage}_ — all properties, including inherited:`);
      lines.push(...resolvedInterfaceProps(target, d, display));
    } else {
      for (const m of d.members) if (isPublicMember(m)) lines.push(clip(oneLine(m.getText(sf))));
    }
  } else if (ts.isEnumDeclaration(d)) {
    kind = 'enum';
    for (const m of d.members) lines.push(clip(oneLine(m.getText(sf))));
  } else if (ts.isFunctionDeclaration(d)) {
    kind = 'function';
    for (const fd of decls.filter(ts.isFunctionDeclaration)) lines.push(clip(oneLine(fd.getText(sf))));
  } else if (ts.isTypeAliasDeclaration(d)) {
    kind = 'type'; lines.push(clip(oneLine(d.getText(sf)), 600));
  } else if (ts.isVariableDeclaration(d)) {
    kind = 'const'; lines.push(clip(oneLine(d.getText(sf)), 400));
  } else if (ts.isModuleDeclaration(d)) {
    kind = 'namespace';
  } else {
    kind = ts.SyntaxKind[d.kind];
  }
  // A namespace — alone, or merged with a class, function or enum of the same name —
  // contributes its members; without this they would vanish from the surface.
  let nested = [];
  if (decls.some(ts.isModuleDeclaration)) {
    const ns = namespaceMembers(target, display);
    if (kind !== 'namespace' && (ns.lines.length || ns.nested.length)) lines.push('_namespace members:_');
    lines.push(...ns.lines);
    for (const [, name] of ns.nested) lines.push(`_see ${name}_`);
    nested = ns.nested;
  }
  if (incompleteBases.has(display)) {
    lines.unshift('_base types did not fully resolve (see Unresolved references): inherited members may be missing and types printed for them may be wrong; check the installed source before citing them._');
  }
  out.set(key, { kind, name: display, importPaths: new Set([importPath]), lines });
  for (const [m, name] of nested) record(m, importPath, name);
}

for (const e of entries) {
  const sf = program.getSourceFile(e.file);
  const modSym = sf && checker.getSymbolAtLocation(sf);
  if (!modSym) continue;
  for (const s of checker.getExportsOfModule(modSym)) {
    exportedTargets.add(s.flags & ts.SymbolFlags.Alias ? checker.getAliasedSymbol(s) : s);
  }
}

const perEntry = [];
for (const e of entries) {
  const sf = program.getSourceFile(e.file);
  const modSym = sf && checker.getSymbolAtLocation(sf);
  if (!modSym) { perEntry.push([e.importPath, 0]); continue; }
  const exps = checker.getExportsOfModule(modSym).filter((s) => !s.getName().startsWith('_'));
  perEntry.push([e.importPath, exps.length]);
  for (const s of exps) record(s, e.importPath);
  unresolvedStars(sf, e.importPath);
}

const order = ['class', 'abstract class', 'interface', 'enum', 'function', 'const', 'type', 'namespace'];
const items = [...out.values()].sort((a, b) =>
  (order.indexOf(a.kind) - order.indexOf(b.kind)) || a.name.localeCompare(b.name));

const w = (s = '') => process.stdout.write(`${s}\n`);
w(singleFile
  ? `> File: \`${path.basename(input)}\`. Exported symbols only, comments removed.`
  : `> Package: \`${pkg.name}@${pkg.version}\` (installed). Read with the TypeScript compiler from the shipped type declarations; exported symbols only, comments removed.`);
w();
w('## Import paths');
for (const [p, n] of perEntry) w(`- \`${p}\` — ${n} exports`);
w();
for (const it of items) {
  w(`## ${it.kind} ${it.name}`);
  w(`Exported from: ${[...it.importPaths].map((p) => `\`${p}\``).join(', ')}`);
  if (unresolved.length && computedTypes.has(it.name) && !incompleteBases.has(it.name)) {
    w('_some property types below were computed by the compiler while other references in this package did not resolve; they may be wrong. Check the installed source before citing them._');
  }
  for (const l of it.lines) w(l.startsWith('_') ? l : `- \`${l.replace(/`/g, "'")}\``);
  w();
}
if (unresolved.length) {
  w('## Unresolved references');
  w('TypeScript could not resolve these, so their declarations are not listed above.');
  for (const u of unresolved) w(`- ${u.what} — \`${u.ref.replace(/`/g, "'")}\` (\`${u.importPath}\`)`);
  w();
}
console.error(`js-dts: ${items.length} declarations, ${unresolved.length} unresolved references`);
