Creator Cloud — Trust the Automation (Part 3) Quick How-To ✅
0) Pick ONE folder naming scheme (do this first)

Right now your examples mix Scripts/scripts/bin/Logs/logs and casing. On Linux, case matters.

Use this (recommended, matches what we built):

Scripts: /media/ANT_Files/CreatorCloud/bin/

Logs: /media/ANT_Files/CreatorCloud/logs/

Config: /media/ANT_Files/CreatorCloud/config/

Index/DB: /media/ANT_Files/CreatorCloud/index/

If you already have other names, no worries — just keep it consistent.

1) Create folder structure (fresh system)

Copy/paste:

mkdir -p /media/ANT_Files/CreatorCloud/{bin,logs,config,index/db,index/state,index/locks,Library}

Quick check (no tree needed):

find /media/ANT_Files/CreatorCloud -maxdepth 2 -type d
2) Put scripts where they belong

You’ll have:

auto_ingest.sh → /media/ANT_Files/CreatorCloud/bin/auto_ingest.sh

ingest_watch.sh → /media/ANT_Files/CreatorCloud/bin/ingest_watch.sh

Make them executable:

chmod +x /media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
chmod +x /media/ANT_Files/CreatorCloud/bin/ingest_watch.sh

Quick confirm:

ls -lah /media/ANT_Files/CreatorCloud/bin
3) Optional: Create config file (recommended)

Create:

/media/ANT_Files/CreatorCloud/config/ingest.env

Example (copy/paste):

cat > /media/ANT_Files/CreatorCloud/config/ingest.env <<'EOF'
MEDIA_GLOB="/media/*"
IGNORE_MOUNTS_REGEX="^(ANT_Files|ZimaOS-HD)$"
PROCESSED_TTL_SECONDS="7200"
MIN_FREE_GB="10"
SAFE_COPY_MODE="1"
POLL_SECONDS="5"
AUTO_INGEST_PATH="/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh"
EOF
✅ Proof Run (B-Roll Friendly)
A) Manual ingest test (baseline proof)

Run ingest once:

/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh

Show the summary (quick proof):

tail -n 6 /media/ANT_Files/CreatorCloud/logs/ingest_summary.log

Show more summary (for B-roll):

tail -n 20 /media/ANT_Files/CreatorCloud/logs/ingest_summary.log
B) Prove duplicates are being skipped

Insert the same card twice, then run ingest twice:

/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh

Now show “dup skipped” evidence:

grep -E "dup_skipped=" -n /media/ANT_Files/CreatorCloud/logs/ingest.log | tail -n 20
C) “Trust proof” — hash DB growth

Count entries:

wc -l /media/ANT_Files/CreatorCloud/index/db/file_hashes.sha1

Show last few hashes:

tail -n 5 /media/ANT_Files/CreatorCloud/index/db/file_hashes.sha1
D) Prove locking prevents double-runs (the “no chaos” clip)

Run ingest, then quickly run it again:

/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh &
/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh

Now show lock message:

grep -E "LOCK busy" -n /media/ANT_Files/CreatorCloud/logs/ingest.log | tail -n 10
✅ Run Watcher in the Background (manual test)

Start it:

nohup /media/ANT_Files/CreatorCloud/bin/ingest_watch.sh >/media/ANT_Files/CreatorCloud/logs/ingest_watch.nohup.log 2>&1 &

Confirm it’s running:

ps | grep ingest_watch | grep -v grep

Watch the watcher log live:

tail -f /media/ANT_Files/CreatorCloud/logs/ingest_watch.log

Stop it (if needed):

pkill -f ingest_watch.sh
✅ Make Watcher Survive Reboot (systemd — correct order)

We’ll create two systemd units:

ingest-watch.service (always running, starts after storage)

(Optional) ingest-watch.timer not needed because watcher is a daemon loop.

1) Create the service

Copy/paste:

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

# Logging (journalctl will also capture it)
WorkingDirectory=/media/ANT_Files/CreatorCloud

[Install]
WantedBy=multi-user.target
EOF

Reload systemd:

systemctl daemon-reload

Enable at boot + start now:

systemctl enable --now creatorcloud-ingest-watch.service

Check status:

systemctl status creatorcloud-ingest-watch.service --no-pager

Live logs (great B-roll):

journalctl -u creatorcloud-ingest-watch.service -f
✅ “Are things running?” quick checks (the sanity panel)
Watcher running?
systemctl is-active creatorcloud-ingest-watch.service
Latest ingest summary:
tail -n 15 /media/ANT_Files/CreatorCloud/logs/ingest_summary.log
Ingest errors?
grep -iE "error|fail|warn" /media/ANT_Files/CreatorCloud/logs/ingest.log | tail -n 30
Notes (important, but short) ⚠️

If /media/ANT_Files isn’t mounted yet at boot, systemd will still start the watcher and it will retry.

The ingest script has:

✅ locking (prevents overlapping runs)

✅ processed TTL (stops constant re-ingest)

✅ hash DB (proves duplicates are skipped)
