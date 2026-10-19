"""Remove the App ID from every text file under a results folder.

    python3 -I redact.py <dir>

Sendbird endpoints carry the App ID in their host names (api-<app id>.sendbird.com), so logs and
console errors can contain it in any letter case. The value comes from RT_APP_ID.
`<name>.raw` files are written out as `<name>` without the value and then removed.
"""
import os
import re
import sys

TEXT = (".json", ".jsonl", ".log", ".txt", ".raw", ".xml", ".md")


def main():
    if len(sys.argv) != 2:
        print("usage: redact.py <dir>", file=sys.stderr)
        return 64
    value = os.environ.get("RT_APP_ID", "")
    if not value:
        return 0
    pat = re.compile(re.escape(value), re.I)
    for d, _, names in os.walk(sys.argv[1]):
        for n in names:
            if not n.endswith(TEXT):
                continue
            p = os.path.join(d, n)
            try:
                text = open(p, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            clean = pat.sub("<app-id>", text)
            if n.endswith(".raw"):
                open(p[:-4], "w", encoding="utf-8").write(clean)
                os.remove(p)
            elif clean != text:
                open(p, "w", encoding="utf-8").write(clean)
    return 0


if __name__ == "__main__":
    sys.exit(main())
