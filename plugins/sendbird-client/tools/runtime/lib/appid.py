"""Find how a project reads its Sendbird App ID, and hand the App ID to it that way.

    python3 -I appid.py detect <project-dir>   print what was found (JSON), change nothing
    python3 -I appid.py apply <project-dir>    also edit the copy where the App ID is a file value

Only the project's own configuration is touched, never Sendbird code: a value the project reads
from the environment, a build setting, or a Gradle property is passed at build or launch time by
the host driver (this script lists the names under "env", "buildSettings", "gradleProperties");
only when the project keeps the App ID as a placeholder value in a config file (the generated
code tells the customer to replace it) is that value replaced in the copy. A project whose config
file already holds a real App ID ("configured") is run as it is, and only when that value is the
App ID the run was given: user B has to join the same application.
The App ID is read from RT_APP_ID and never printed; neither is a configured value.
"""
import json
import os
import re
import sys

SKIP_DIRS = {"node_modules", ".git", "build", ".build", ".gradle", "DerivedData", "Pods", ".sendbird-client",
             ".sendbird-client", "ios", "android"}
CODE_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".swift", ".kt", ".kts", ".java", ".plist", ".yml",
            ".yaml", ".xcconfig", ".properties", ".xml", ".json")
APP_ID_NAME = r"[A-Za-z_]*(?:APP_?ID|AppId|appId|app_id)[A-Za-z_]*"
# A value a customer is told to replace: empty, all zeros, or a YOUR_/<...>/REPLACE marker.
PLACEHOLDER = r"(?:|0{8}-0{4}-0{4}-0{4}-0{12}|YOUR[A-Z_ -]*|<[^>]*>|REPLACE[A-Z_ -]*|your[-_ ]?app[-_ ]?id)"


def files(root):
    for d, dirs, names in os.walk(root):
        rel = os.path.relpath(d, root)
        # ios/ and android/ are skipped only for React Native (native shells), not native apps
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS or (x in ("ios", "android") and not is_rn(root))]
        for n in names:
            if n.endswith(CODE_EXT) and n not in ("package-lock.json", "package.json", "tsconfig.json", "profile.json"):
                yield os.path.join(d, n), (n if rel == "." else os.path.join(rel, n))


_rn = {}


def is_rn(root):
    if root not in _rn:
        try:
            pkg = json.load(open(os.path.join(root, "package.json")))
            deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
            _rn[root] = "react-native" in deps
        except Exception:
            _rn[root] = False
    return _rn[root]


def detect(root):
    found = {"env": set(), "buildSettings": set(), "gradleProperties": set(), "literals": [], "configured": []}
    env_patterns = [
        r"process\.env\.(" + APP_ID_NAME + r")",
        r"import\.meta\.env\.(" + APP_ID_NAME + r")",
        r"environment\[\"(" + APP_ID_NAME + r")\"\]",
        r"System\.getenv\(\"(" + APP_ID_NAME + r")\"\)",
        r"environmentVariable\(\"(" + APP_ID_NAME + r")\"\)",
    ]
    gradle_patterns = [r"(?:findProperty|gradleProperty|property)\(\"(" + APP_ID_NAME + r")\"\)"]
    for path, rel in files(root):
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for p in env_patterns:
            found["env"].update(re.findall(p, text))
        if rel.endswith((".kts", ".gradle")):
            for p in gradle_patterns:
                found["gradleProperties"].update(re.findall(p, text))
        if rel.endswith((".plist", ".yml", ".yaml")):
            # SendbirdAppId: $(SENDBIRD_APP_ID)  /  <string>$(SENDBIRD_APP_ID)</string>
            found["buildSettings"].update(re.findall(r"\$\((" + APP_ID_NAME + r")\)", text))
        if rel.endswith(".properties"):
            for name in re.findall(r"^(" + APP_ID_NAME + r")\s*=", text, re.M):
                found["gradleProperties"].add(name)
        # const SENDBIRD_APP_ID = '';   let appId = "YOUR_APP_ID"   (config files the customer edits)
        for m in re.finditer(r"\b(?:export\s+)?(?:const|let|var|val|static\s+let)\s+(" + APP_ID_NAME +
                             r")\s*(?::\s*[A-Za-z?]+\s*)?=\s*(['\"])(" + PLACEHOLDER + r")\2", text):
            found["literals"].append({"file": rel, "name": m.group(1), "line": text[:m.start()].count("\n") + 1})
        # const SENDBIRD_APP_ID = 'A1B2...'   (a config file that already holds a real value)
        for m in re.finditer(r"\b(?:export\s+)?(?:const|let|var|val|static\s+let)\s+(" + APP_ID_NAME +
                             r")\s*(?::\s*[A-Za-z?]+\s*)?=\s*(['\"])([^'\"\n]+)\2", text):
            if not re.fullmatch(PLACEHOLDER, m.group(3)):
                found["configured"].append({"file": rel, "name": m.group(1), "line": text[:m.start()].count("\n") + 1})
        if rel.endswith(".xml"):
            for m in re.finditer(r"<string name=\"(" + APP_ID_NAME.lower() + r")\">(" + PLACEHOLDER + r")</string>", text, re.I):
                found["literals"].append({"file": rel, "name": m.group(1), "line": text[:m.start()].count("\n") + 1})
        # "sendbirdAppId": ""   (a JSON config the app imports, such as React Native's app.json). Only
        # keys that name Sendbird: a JSON appId is often another service's (Firebase's mobilesdk_app_id)
        if rel.endswith(".json"):
            for m in re.finditer(r"\"(" + APP_ID_NAME + r")\"\s*:\s*\"([^\"\n]*)\"", text):
                if "sendbird" not in m.group(1).lower():
                    continue
                kind = "literals" if re.fullmatch(PLACEHOLDER, m.group(2)) else "configured"
                found[kind].append({"file": rel, "name": m.group(1), "line": text[:m.start()].count("\n") + 1})
    out = {k: sorted(v) if isinstance(v, set) else v for k, v in found.items()}
    # A Gradle property that is only defined (gradle.properties) but never read is still how the
    # build reads it when a build script uses findProperty; keep both lists.
    out["how"] = [k for k in ("env", "buildSettings", "gradleProperties", "literals", "configured") if out[k]]
    return out


def apply(root, info):
    value = os.environ.get("RT_APP_ID", "")
    if not value:
        raise SystemExit("RT_APP_ID is not set")
    replaced = []
    # Literals are replaced only when the project has no other way to read the App ID: a project
    # that reads the environment or a build setting gets the value there, and its fallback literal
    # stays as the plugin wrote it.
    if not (info["env"] or info["buildSettings"] or info["gradleProperties"]):
        for lit in info["literals"]:
            path = os.path.join(root, lit["file"])
            text = open(path, encoding="utf-8").read()
            lines = text.split("\n")
            i = lit["line"] - 1
            if lit["file"].endswith(".xml"):
                new = re.sub(r"(<string name=\"" + re.escape(lit["name"]) + r"\">)[^<]*(</string>)", r"\g<1>" + value + r"\g<2>", lines[i])
            elif lit["file"].endswith(".json"):
                new = re.sub(r"(\"" + re.escape(lit["name"]) + r"\"\s*:\s*)\"[^\"]*\"",
                             lambda m: m.group(1) + json.dumps(value), lines[i], count=1)
            else:
                new = re.sub(r"(\b" + re.escape(lit["name"]) + r"\s*(?::\s*[A-Za-z?]+\s*)?=\s*)(['\"])[^'\"]*\2",
                             lambda m: m.group(1) + m.group(2) + value + m.group(2), lines[i], count=1)
            if new != lines[i]:
                lines[i] = new
                open(path, "w", encoding="utf-8").write("\n".join(lines))
                replaced.append(lit["file"])
    info = dict(info)
    info["replacedIn"] = sorted(set(replaced))
    # Nothing to hand over: the project already holds an App ID. Use it only when it is the one
    # this run was given, since user B connects to that application.
    if not (info["env"] or info["buildSettings"] or info["gradleProperties"] or replaced) and info["configured"]:
        same = []
        for c in info["configured"]:
            line = open(os.path.join(root, c["file"]), encoding="utf-8").read().split("\n")[c["line"] - 1]
            sep = ":" if c["file"].endswith(".json") else "="
            m = re.search(r"(['\"])([^'\"\n]+)\1", line.split(sep, 1)[1] if sep in line else "")
            if m and m.group(2) == value:
                same.append(c)
        if not same:
            info["error"] = ("the project's App ID (" + ", ".join(f"{c['file']}:{c['line']}" for c in info["configured"]) +
                             ") is not the App ID given to the run")
            info["how"] = []
        else:
            info["how"] = ["configured"]
    return info


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("detect", "apply"):
        print("usage: appid.py detect|apply <project-dir>", file=sys.stderr)
        return 64
    root = sys.argv[2]
    info = detect(root)
    if sys.argv[1] == "apply":
        info = apply(root, info)
    print(json.dumps(info))
    return 0 if info["how"] else 1


if __name__ == "__main__":
    sys.exit(main())
