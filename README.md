## Related Content
This project is built and documented alongside the **Creator Cloud** YouTube series on Alpha Nerd Tech, where I walk through the full workflow, hardware, and automation step by step.

▶️ YouTube: https://www.youtube.com/@alphanerdtravels

# Creator Cloud 🚀
Real-world creator workflow for **ingest → organize → edit → backup**, built in public by **AlphaNerd Tech**.

This repo contains the scripts, configs (examples only), and documentation used in the YouTube **Creator Cloud** series — starting with **ZimaBoard 2**, and expanding over time.

## What this project does (high-level)
- Automatically ingests footage from SD cards / media
- Organizes footage into a predictable folder structure
- Moves or syncs content to your NAS / storage (Unraid, SMB shares, etc.)
- Supports a creator workflow where your editing machine (Mac/PC) always sees the latest media

## Series Hardware (current baseline)
- ZimaBoard 2 (ingest + automation)
- NAS systems (Unraid-based), shared to editing workstation
- Editing workstation (Mac Studio)

## Repo Map
- `docs/` → How the system works (overview, diagrams, troubleshooting)
- `zima-board-2/ingest/` → SD ingest scripts + installer
- `zima-board-2/sync/` → Auto-sync scripts + systemd timer/service
- `zima-board-2/monitoring/` → Status + log helper scripts
- `unraid/` → Notes on shares, storage layout, and practical setup

## Quick Start
1. Start here: `docs/00-overview.md`
2. ZimaBoard ingest: `zima-board-2/ingest/README.md`
3. Auto-sync: `zima-board-2/sync/README.md`

## Safety / Disclaimer ⚠️
These scripts can move and delete files if misconfigured.
Use the example config files, test with dummy data, and don’t run anything you don’t understand.
You are responsible for your data.

## Support / Updates
I’ll update this repo alongside the YouTube series.  
If you run into issues, open a GitHub Issue with:
- your hardware
- what step you’re on
- logs (redact private info)

— Scott / AlphaNerd Tech
▶️ YouTube: https://www.youtube.com/@alphanerdtravels
