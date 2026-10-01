# Tier-3 lazy detectors

These are NOT scanned at setup. `registry.json` lists, per area, the dependency/file
signals a skill should grep for ONLY when the customer's question touches that area
(spec §4.x Tier-3). Keeping them lazy avoids slow startup scans and confirmation fatigue.
A skill that needs e.g. the navigation framework greps the listed signals on demand.
