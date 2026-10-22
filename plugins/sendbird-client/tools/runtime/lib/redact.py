"""Remove the App ID from every text file under a results folder, or from a stream.

    python3 -I redact.py <dir>
    <command> | python3 -I redact.py -

Sendbird endpoints carry the App ID in their host names (api-<app id>.sendbird.com), so logs and
console errors can contain it in any letter case. The value comes from RT_APP_ID.
`<name>.raw` files are written out as `<name>` without the value and then removed.
With `-`, standard input is copied to standard output line by line without the value, so a host
driver's progress lines reach the terminal (and the agent reading it) already redacted.
"""
import os
import re
import sys

TEXT = (".json", ".jsonl", ".log", ".txt", ".raw", ".xml", ".md")


def stream(value):
    pat = re.compile(re.escape(value.encode()), re.I) if value else None
    out = sys.stdout.buffer
    for line in iter(sys.stdin.buffer.readline, b""):
        out.write(pat.sub(b"<app-id>", line) if pat else line)
        out.flush()
    return 0


def main():
    if len(sys.argv) != 2:
        print("usage: redact.py <dir> | redact.py -", file=sys.stderr)
        return 64
    value = os.environ.get("RT_APP_ID", "")
    if sys.argv[1] == "-":
        return stream(value)
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
