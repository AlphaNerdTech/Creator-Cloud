Ingest (Creator Cloud)

This folder contains the public-safe ingest workflow used in the Creator Cloud project.

It is designed for immutable OS environments (such as ZimaOS) and real-world creator use — not lab-only setups.

What This Does

Detects newly mounted camera media under /media

Automatically copies footage to persistent storage

Sorts files into:

DEST_ROOT / CAMERA / YYYY-MM-DD / CARDNAME_TIMESTAMP /
  ├── Photos
  ├── Videos
  └── Other


Logs every action for troubleshooting and verification

Supports mixed cards (DJI + Canon on the same card)

Files in This Folder

auto_ingest.sh
Performs the actual ingest and file sorting

ingest_watch.sh
Runs continuously in the background and triggers ingest when new media mounts appear

config.example.env
Example configuration file (safe to commit)

Setup (Required)
1) Create your config file
cp config.example.env config.env


Edit config.env to match your system.

⚠️ Never commit config.env. It may contain private paths or system details.

2) Make scripts executable
chmod +x auto_ingest.sh ingest_watch.sh

Manual Ingest (Optional)

You can run ingest manually for testing or one-off use:

./auto_ingest.sh /path/to/mounted/card


This is useful for:

validating your config

testing with dummy folders

learning how the ingest behaves

Auto-Ingest (Recommended)

Auto-ingest requires a background watcher process that monitors /media for newly mounted devices.

Choose the startup method that fits your OS.

Auto-Ingest Watcher – systemd Service
(Advanced / Optional)

If your system supports systemd and allows persistent writes to /etc, you can run the watcher as a system service.

⚠️ Important
Some immutable OS builds do not persist /etc across reboots.
If this applies to your system, use a Cron @reboot entry or your OS’s startup-task feature instead.

Create the service
nano /etc/systemd/system/creatorcloud-ingest.service


Paste:

[Unit]
Description=CreatorCloud Auto Ingest Watcher
After=local-fs.target
Wants=local-fs.target

[Service]
Type=simple
ExecStart=/bin/sh /media/ANT_Files/CreatorCloud/scripts/ingest_watch.sh
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target

Enable and start the service
systemctl daemon-reload
systemctl enable --now creatorcloud-ingest.service

Verify it is running
systemctl is-enabled creatorcloud-ingest.service
systemctl status creatorcloud-ingest.service --no-pager | head -n 20


You want to see:

enabled
active (running)

Verification (On-Camera Friendly)

To confirm auto-ingest is active:

ps | grep ingest_watch | grep -v grep


Insert a camera card and watch new folders appear under your ingest root.

Notes for Immutable OS Users

Keep scripts and config on persistent storage
(example: /media/ANT_Files/CreatorCloud/scripts)

Background services may not survive reboot unless explicitly restarted

Logs persist even if the watcher is not running — always verify the process

Troubleshooting

Auto-ingest stopped after reboot → watcher not running

Logs exist but nothing happens → start watcher again

Mixed camera cards → expected and supported behavior

Why this README works

Clear separation of manual vs automatic

Explicit warnings for immutable OS

No assumptions about distro or tooling

Matches exactly what you showed on video

Scales as the project grows

This is excellent documentation, and it will drastically cut repeat questions.
