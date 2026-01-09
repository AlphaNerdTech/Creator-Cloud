## Ingest (Creator Cloud)

This folder contains the **public-safe ingest workflow** used in the Creator Cloud project.

It is designed for **immutable OS environments** (such as ZimaOS) and real-world creator use — not lab-only setups.

---

## What This Does

- Detects newly mounted camera media under `/media`
- Automatically copies footage to persistent storage
- Sorts files into a predictable structure:

```
DEST_ROOT / CAMERA / YYYY-MM-DD / CARDNAME_TIMESTAMP /
  ├── Photos
  ├── Videos
  └── Other`
```
- Logs every action for troubleshooting and verification
- Supports mixed cards (DJI + Canon on the same card)

## Files in This Folder
`auto_ingest.sh`
Performs the actual ingest and file sorting

`ingest_watch.sh`
Runs continuously in the background and triggers ingest when new media mounts appear

`config.example.env`
Example configuration file (safe to commit)

Setup (Required)
1) Create your config file
```
cp config.example.env config.env
```
Edit config.env to match your system.

2) Make scripts executable
```
chmod +x auto_ingest.sh ingest_watch.sh
```

Manual Ingest (Optional)
You can run ingest manually for testing or one-off use:
```
./auto_ingest.sh /path/to/mounted/card
```

## Auto-Ingest
Auto-ingest requires a background watcher process that monitors /media for newly mounted devices.

Choose the startup method that fits your OS.

Auto-Ingest Watcher (systemd – Advanced / Optional)
If your system supports systemd and allows persistent writes to /etc, you can run the watcher as a service.

⚠️ Some immutable OS builds do not persist /etc across reboots.

Create the service
```
nano /etc/systemd/system/creatorcloud-ingest.service
```

Paste:

```
[Unit]
Description=CreatorCloud Auto Ingest Watcher
After=local-fs.target
Wants=local-fs.target

[Service]
Type=simpleival
ExecStart=/bin/sh /media/ANT_Files/CreatorCloud/scripts/ingest_watch.sh
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
```
Enable and start the service
```
systemctl daemon-reload
systemctl enable --now creatorcloud-ingest.service
```
Verify service status
```
systemctl is-enabled creatorcloud-ingest.service
systemctl status creatorcloud-ingest.service --no-pager | head -n 20
```
You want to see:
```
enabled
active (running)
```


---

