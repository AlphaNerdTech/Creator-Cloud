# Ingest (Creator Cloud)

This folder contains the public-safe ingest workflow used in the Creator Cloud project.

This is the automation shown in:

🎬 Stop Managing Files – Part 3  
“Trust the Automation”

---

## What This Does

The ingest workflow:

- Detects newly mounted camera media under `/media`
- Automatically copies footage to persistent storage
- Sorts files into a predictable structure
- Prevents duplicate imports
- Logs everything for traceability

Designed for:
- ZimaOS (immutable-style environments)
- Real-world creator use
- Not lab-only demos

---

## Folder Structure

Media is organized into:


DEST_ROOT /
CAMERA /
YYYY-MM-DD /
CARDNAME_TIMESTAMP /
Photos /
Videos /
Other /


Example:


Library/
DJI/
2026-01-03/
sdd1-usb-Generic_MassStor_162246_160315/
Videos/
Photos/


---

## Files In This Folder

| File | Purpose |
|------|----------|
| `auto_ingest.sh` | Main ingest automation script |
| `ingest_watch.sh` | Loop/watcher script |
| `config.example.env` | Example configuration file |

---

## Quick Start

1️⃣ Copy the example config:


cp config.example.env config.env


2️⃣ Edit your paths inside `config.env`

3️⃣ Run ingest manually:


sudo bash auto_ingest.sh


4️⃣ Or start watcher:


sudo bash ingest_watch.sh


---

## Logging

Logs are written to:


/media/ANT_Files/CreatorCloud/logs/


- ingest.log  
- ingest_summary.log  

Monitor in real time:


tail -f /media/ANT_Files/CreatorCloud/logs/ingest.log


---

## Design Philosophy

This system is built around one principle:

> Trust the automation.

When configured correctly:

- You plug in a card
- It copies
- It sorts
- It verifies
- It logs
- You move on with your life

No manual folder management.  
No guessing where footage went.  
No duplicate imports.

---

## Safety Notice ⚠️

This script moves and copies files.

- Test with non-critical data first  
- Verify DEST_ROOT before running  
- Read the script if you are unsure  

You are responsible for your data.

---

## Related Content

This project is built and documented alongside the Creator Cloud YouTube series on Alpha Nerd Tech.

▶️ YouTube: https://www.youtube.com/@alphanerdtravels
