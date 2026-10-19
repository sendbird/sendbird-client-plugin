"""Deprecated declarations of an installed Sendbird SDK, and where a project uses them.

    python3 -I deprecations.py swift <api-surface.md>        declarations from read-swiftinterface.sh output
    python3 -I deprecations.py javap <javap -v text>         declarations from `javap -v -public` output
    python3 -I deprecations.py usages <project-dir> <swift|kotlin> <declarations.tsv>

The first two print one tab-separated line per deprecated declaration:
    <kind: func|var|type>  <name>  <overloaded: yes|no>  <message>  <declaration>
`usages` reads those lines and prints one line per use in the project's source files:
    DEPRECATED: <file>:<line>: <name> — <message> [declaration: <declaration>]
A use is found by name (a call, a member access, or a type reference), so a name that also has a
declaration that is not deprecated is marked "(overloaded: check the call)". Nothing is compiled.
"""
import os
import re
import sys

SKIP_DIRS = {"node_modules", ".git", "build", ".build", ".gradle", "DerivedData", "Pods", "SourcePackages",
             ".sendbird-client", ".sendbird-client", ".idea", ".swiftpm"}


def clean(s):
    return re.sub(r"\s+", " ", s or "").strip()


# --- Swift: the rendered surface keeps attributes, e.g.
# - `@available(*, deprecated, message: "Use connect") open func legacyConnect()`
# _@available(*, deprecated, renamed: "NewType") open class OldType : NSObject_
SWIFT_DECL = re.compile(r"\b(func|var|let|case|class|struct|enum|protocol|typealias|actor)\s+`?([A-Za-z_][A-Za-z0-9_]*)")


def swift_message(attr):
    parts = []
    for key in ("message", "renamed"):
        m = re.search(key + r':\s*"((?:[^"\\]|\\.)*)"', attr)
        if m:
            parts.append(("renamed to " if key == "renamed" else "") + m.group(1))
    return "; ".join(parts) or "deprecated"


def swift(path):
    seen_plain = set()
    found = []
    for raw in open(path, encoding="utf-8", errors="replace"):
        line = raw.strip()
        m = re.match(r"^(?:- `(.*)`|_(.*)_)$", line)
        if not m:
            continue
        decl = m.group(1) or m.group(2)
        d = SWIFT_DECL.search(re.sub(r"@\w+(\((?:[^()\"]|\"(?:[^\"\\]|\\.)*\")*\))?", " ", decl))
        if not d:
            continue
        kind = "type" if d.group(1) in ("class", "struct", "enum", "protocol", "typealias", "actor") else (
            "func" if d.group(1) == "func" else "var")
        name = d.group(2)
        attrs = re.findall(r"@available\((?:[^()\"]|\"(?:[^\"\\]|\\.)*\")*\)", decl)
        dep = [a for a in attrs if re.search(r"\bdeprecated\b", a) and not re.search(r"\bunavailable\b", a)]
        if dep:
            found.append((kind, name, swift_message(dep[0]), clean(decl)))
        else:
            seen_plain.add(name)
    return found, seen_plain


# --- javap -v: a member is a 2-space declaration line ending in ';', followed by its attributes.
# Kotlin puts a property's annotations on a synthetic `getX$annotations()` method.
JAVA_MEMBER = re.compile(r"^  (?:[a-z]+ )*[^ ()]+(?: [^ ()]+)? ([A-Za-z_$][A-Za-z0-9_$]*)(\(.*\))?(?: throws [^;]+)?;$")


def javap(path):
    found, seen_plain = [], set()
    cls = ""
    cur = None  # [name, is_method, decl, deprecated, message]

    def close():
        if not cur:
            return
        name, is_method, decl, deprecated, msg = cur
        kind = "func" if is_method else "var"
        if name.endswith("$annotations"):
            prop = re.sub(r"^(get|is)", "", name[: -len("$annotations")])
            name, kind = prop[:1].lower() + prop[1:], "var"
        if "$" in name or name in ("<init>", "<clinit>"):
            return
        if deprecated:
            found.append((kind, name, msg or "deprecated", decl))
        else:
            seen_plain.add(name)

    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        mc = re.match(r"^(?:public |protected )?(?:abstract |final |static )*(?:class|interface|enum|@interface) ([\w.$]+)", line)
        if mc:
            close(); cur = None
            cls = mc.group(1).split(".")[-1].split("$")[-1]
        elif line == "}":
            close(); cur = None
            # class attributes follow the closing brace
            j = i + 1
            block = []
            while j < len(lines) and not re.match(r"^(Classfile|public |final |abstract |class |interface )", lines[j]):
                block.append(lines[j]); j += 1
            text = "\n".join(block)
            if re.search(r"^Deprecated: true", text, re.M) and cls:
                found.append(("type", cls, kotlin_message(text) or "deprecated", cls))
            i = j
            continue
        else:
            mm = JAVA_MEMBER.match(line)
            if mm:
                close()
                cur = [mm.group(1), mm.group(2) is not None, clean(line), False, ""]
            elif cur is not None and re.match(r"^    Deprecated: true", line):
                cur[3] = True
            elif cur is not None and line.strip().startswith("kotlin.Deprecated("):
                block = []
                j = i
                while j < len(lines) and lines[j].strip() != "" and not JAVA_MEMBER.match(lines[j]):
                    block.append(lines[j]); j += 1
                cur[4] = kotlin_message("\n".join(block))
        i += 1
    close()
    return found, seen_plain


def kotlin_message(text):
    parts = []
    m = re.search(r'message="((?:[^"\\]|\\.)*)"', text)
    if m:
        parts.append(m.group(1))
    m = re.search(r'expression="((?:[^"\\]|\\.)*)"', text)
    if m and m.group(1):
        parts.append("replace with " + m.group(1))
    return "; ".join(parts)


def emit(found, seen_plain):
    names = {}
    for kind, name, msg, decl in found:
        names.setdefault((kind, name), (msg, decl))
    for (kind, name), (msg, decl) in sorted(names.items()):
        print("\t".join([kind, name, "yes" if name in seen_plain else "no", clean(msg), decl]))


def usages(root, lang, tsv):
    exts = (".swift",) if lang == "swift" else (".kt", ".java")
    decls = []
    for raw in open(tsv, encoding="utf-8"):
        parts = raw.rstrip("\n").split("\t")
        if len(parts) == 5:
            decls.append(parts)
    pats = []
    for kind, name, overloaded, msg, decl in decls:
        n = re.escape(name)
        if kind == "type":
            rx = re.compile(r"(?<![A-Za-z0-9_.])" + n + r"\b")
        elif kind == "func":
            rx = re.compile(r"(?:\.|\b)" + n + r"\s*[({]" if lang == "swift" else r"\." + n + r"\s*[({]|\b" + n + r"\s*\(")
        else:
            rx = re.compile(r"\." + n + r"\b")
        pats.append((rx, name, overloaded, msg, decl))
    out = []
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not x.endswith((".xcodeproj", ".xcworkspace")))
        for f in sorted(files):
            if not f.endswith(exts):
                continue
            p = os.path.join(d, f)
            rel = os.path.relpath(p, root)
            try:
                text = open(p, encoding="utf-8", errors="replace").read().split("\n")
            except OSError:
                continue
            for no, line in enumerate(text, 1):
                code = re.sub(r"//.*$", "", line)
                if re.match(r"\s*(\*|/\*)", code):
                    continue
                for rx, name, overloaded, msg, decl in pats:
                    if rx.search(code):
                        note = " (overloaded: check the call)" if overloaded == "yes" else ""
                        out.append((rel, no, f"DEPRECATED: {rel}:{no}: {name} — {msg}{note} [declaration: {decl}]"))
    for _, _, line in sorted(set(out)):
        print(line)


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] in ("swift", "javap"):
        emit(*(swift(a[1]) if a[0] == "swift" else javap(a[1])))
        return 0
    if len(a) == 4 and a[0] == "usages" and a[2] in ("swift", "kotlin"):
        usages(a[1], a[2], a[3])
        return 0
    print(__doc__, file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main())
