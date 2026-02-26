# Creator Cloud — Trust the Automation (Part 3)
### Quick How-To Guide
Remember, My pool name is ANT_Files and my structure is /ANT_Files/CreatorCloud/
You will want to replace that with your own structure.
---

## ✅ Step 0 — Pick ONE Folder Naming Scheme *(do this first)*

> ⚠️ **Linux is case-sensitive.** Right now your examples mix `Scripts/`, `scripts/`, `bin/`, `Logs/`, `logs/`, and inconsistent casing. Pick one and stick to it.

**Recommended structure (matches what we built):**

| Purpose   | Path                                          |
|-----------|-----------------------------------------------|
| Scripts   | `/media/ANT_Files/CreatorCloud/bin/`          |
| Logs      | `/media/ANT_Files/CreatorCloud/logs/`         |
| Config    | `/media/ANT_Files/CreatorCloud/config/`       |
| Index/DB  | `/media/ANT_Files/CreatorCloud/index/`        |

If you already have other names, no worries — just keep it consistent.

---

## ✅ Step 1 — Create Folder Structure *(fresh system)*

Copy/paste into your terminal:

```bash
mkdir -p /media/ANT_Files/CreatorCloud/{bin,logs,config,index/db,index/state,index/locks,Library}
```

Quick check *(no `tree` needed)*:

```bash
find /media/ANT_Files/CreatorCloud -maxdepth 2 -type d
```

---

## ✅ Step 2 — Put Scripts Where They Belong

You'll have two scripts to place:

| Script           | Destination                                               |
|------------------|-----------------------------------------------------------|
| `auto_ingest.sh` | `/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh`        |
| `ingest_watch.sh`| `/media/ANT_Files/CreatorCloud/bin/ingest_watch.sh`       |

Make them executable:

```bash
chmod +x /media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
chmod +x /media/ANT_Files/CreatorCloud/bin/ingest_watch.sh
```

Quick confirm:

```bash
ls -lah /media/ANT_Files/CreatorCloud/bin
```

---

## ✅ Step 3 — Create Config File *(recommended)*

Create `/media/ANT_Files/CreatorCloud/config/ingest.env`:

```bash
cat > /media/ANT_Files/CreatorCloud/config/ingest.env <<'EOF'
MEDIA_GLOB="/media/*"
IGNORE_MOUNTS_REGEX="^(ANT_Files|ZimaOS-HD)$"
PROCESSED_TTL_SECONDS="7200"
MIN_FREE_GB="10"
SAFE_COPY_MODE="1"
POLL_SECONDS="5"
AUTO_INGEST_PATH="/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh"
EOF
```

---

## 🎬 Proof Run (B-Roll Friendly)

### A) Manual Ingest Test — Baseline Proof

Run ingest once:

```bash
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
```

Show the summary:

```bash
# Quick proof
tail -n 6 /media/ANT_Files/CreatorCloud/logs/ingest_summary.log

# Extended B-roll
tail -n 20 /media/ANT_Files/CreatorCloud/logs/ingest_summary.log
```

---

### B) Prove Duplicates Are Being Skipped

Insert the same card twice, then run ingest twice:

```bash
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
```

Show `dup_skipped` evidence:

```bash
grep -E "dup_skipped=" -n /media/ANT_Files/CreatorCloud/logs/ingest.log | tail -n 20
```

---

### C) "Trust Proof" — Hash DB Growth

Count entries:

```bash
wc -l /media/ANT_Files/CreatorCloud/index/db/file_hashes.sha1
```

Show last few hashes:

```bash
tail -n 5 /media/ANT_Files/CreatorCloud/index/db/file_hashes.sha1
```

---

### D) Prove Locking Prevents Double-Runs *(the "no chaos" clip)*

Run ingest, then immediately run it again:

```bash
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh &
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
```

Show lock message:

```bash
grep -E "LOCK busy" -n /media/ANT_Files/CreatorCloud/logs/ingest.log | tail -n 10
```

---

## ✅ Run Watcher in the Background *(manual test)*

**Start it:**

```bash
nohup /media/ANT_Files/CreatorCloud/bin/ingest_watch.sh \
  >/media/ANT_Files/CreatorCloud/logs/ingest_watch.nohup.log 2>&1 &
```

**Confirm it's running:**

```bash
ps | grep ingest_watch | grep -v grep
```

**Watch the watcher log live:**

```bash
tail -f /media/ANT_Files/CreatorCloud/logs/ingest_watch.log
```

**Stop it (if needed):**

```bash
pkill -f ingest_watch.sh
```

---

## ✅ Make Watcher Survive Reboot *(systemd — correct order)*

We'll create one systemd unit:
- **`creatorcloud-ingest-watch.service`** — always running, starts after storage mounts

> A `.timer` unit is **not needed** because the watcher is already a daemon loop.

### Create the Service

```bash
cat > /etc/systemd/system/creatorcloud-ingest-watch.service <<'EOF'
[Unit]
Description=Creator Cloud Ingest Watcher (Trust the Automation)
After=network-online.target local-fs.target
Wants=network-online.target

[Service]
Type=simple
Environment=ENV_FILE=/media/ANT_Files/CreatorCloud/config/ingest.env
ExecStart=/media/ANT_Files/CreatorCloud/bin/ingest_watch.sh
Restart=always
RestartSec=3
Nice=5
WorkingDirectory=/media/ANT_Files/CreatorCloud

[Install]
WantedBy=multi-user.target
EOF
```

### Enable & Start

```bash
# Reload systemd
systemctl daemon-reload

# Enable at boot + start now
systemctl enable --now creatorcloud-ingest-watch.service
```

### Verify

```bash
# Check status
systemctl status creatorcloud-ingest-watch.service --no-pager

# Live logs (great B-roll)
journalctl -u creatorcloud-ingest-watch.service -f
```

---

## ✅ "Are Things Running?" — Quick Sanity Checks

| Check | Command |
|-------|---------|
| Watcher running? | `systemctl is-active creatorcloud-ingest-watch.service` |
| Latest ingest summary | `tail -n 15 /media/ANT_Files/CreatorCloud/logs/ingest_summary.log` |
| Ingest errors? | `grep -iE "error\|fail\|warn" /media/ANT_Files/CreatorCloud/logs/ingest.log \| tail -n 30` |

---

## ⚠️ Important Notes

- If `/media/ANT_Files` isn't mounted yet at boot, systemd will still start the watcher — it will retry automatically.
- The ingest script includes built-in safeguards:
  - ✅ **Locking** — prevents overlapping runs
  - ✅ **Processed TTL** — stops constant re-ingest
  - ✅ **Hash DB** — proves duplicates are skipped
