# 17 — Uninstall & Reset

This page explains how to safely remove KTStack from your Mac, with options for a complete uninstall or a data reset while keeping the app.

## Understanding uninstall vs. reset

KTStack provides two cleanup options:

| Action | What it does | Data lost | Reversible |
|--------|-------------|-----------|-----------|
| **Reset data** | Stops a service and moves its data aside to a `.removed` folder. App and code remain. | Nothing until you delete the moved data | Yes — restore it from Runtimes |
| **Full uninstall** | Removes the entire app, all services, DNS config, CA trust, and all app data. | Everything | No — requires fresh install |

Choose **reset data** if you want to keep KTStack but start fresh with a service. Choose **full uninstall** if you want to remove KTStack entirely from your Mac.

## Resetting a single service's data

If a database service is corrupted or you just want to start clean with one database:

1. Open the KTStack dashboard and go to the **Services** section.
2. Find the service (MySQL, MariaDB, PostgreSQL, Redis or MongoDB).
3. Click the **menu button** (three dots) next to the service row.
4. Select **Reset Data**.
5. A confirmation dialog appears: "Reset [Service] data? This stops [Service] and moves the active version's data to a .removed folder. The next start creates an empty datastore. You can restore the old data from Runtimes."
6. Click **Reset [Service] data** to confirm.

KTStack stops the service and moves the data for the active version to `~/Library/Application Support/KTStack/data/<service>/.removed/`. The next start creates an empty datastore. To get the old data back, restore it from **Runtimes**; to free the space, move it to the Trash from there.

**If you have a backup**, restore it before the reset, or restore it afterward. See [09 — Database backup & restore](09-database-backup-and-restore.md).

## Full uninstall (in-app)

The easiest way to completely remove KTStack is through the app itself:

1. Open the KTStack dashboard.
2. Click the **gear icon** (⚙) to open Settings.
3. Scroll to the **Maintenance** section.
4. Click **Uninstall…** next to "Reset & Uninstall".
5. A confirmation dialog appears:
   - "Uninstall KTStack and remove all data? This stops all services and permanently deletes app data, runtimes and databases. This cannot be undone."
6. Click **Uninstall / Reset** to proceed (or **Cancel** to abort).
7. KTStack performs the uninstall steps automatically:
   - Stops all running services
   - Disables local DNS and removes `/etc/resolver/.test` (or your custom TLD)
   - Removes shell PATH integration from your `.zshrc` or `.bashrc`
   - Untrusts the local CA from your System Keychain
   - Unregisters the privileged helper (smappservice)
   - Deletes `~/Library/Application Support/KTStack/` (all app data, runtimes, databases)

8. A log window shows the progress of each step. Wait for it to complete and show a final status ("Done" or "Failed").
9. Once complete, you can delete the KTStack app:
   - Open **Finder** and go to **Applications**.
   - Find **KTStack** and drag it to the **Trash**.
   - Empty the Trash.

## Manual uninstall (if in-app method fails)

If KTStack won't launch or the in-app uninstall fails, you can remove it manually:

### 1. Stop services

Stop any services running via KTStack:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.ktstack.*.plist 2>/dev/null
```

### 2. Disable DNS

Remove the local DNS resolver:

```bash
sudo rm -f /etc/resolver/.test
```

(Replace `.test` with your custom TLD if you changed it.)

### 3. Remove shell integration

Edit your shell configuration file and remove the KTStack lines:

**For Zsh** (default on macOS 10.15+):
```bash
nano ~/.zshrc
```

**For Bash**:
```bash
nano ~/.bashrc
```

Find and delete these lines:
```bash
export PATH="/Users/[your-username]/Library/Application Support/KTStack/shims:$PATH"
```

Save and exit (Ctrl+X, then Y, then Enter).

### 4. Untrust the local CA

Open **Keychain Access** and remove the KTStack CA certificate:

1. Open **Applications > Utilities > Keychain Access**.
2. In the search box, type "mkcert" or "KTStack".
3. Find any certificates related to KTStack and select them.
4. Press **Delete** or right-click and choose **Delete**.
5. macOS may ask for your password. Enter it.

### 5. Unregister the privileged helper

If you installed the privileged helper (for DNS support):

```bash
sudo /bin/launchctl bootout system /Library/LaunchDaemons/com.ktstack.helper.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.ktstack.helper.plist
```

### 6. Delete app data

Remove the entire KTStack data directory:

```bash
rm -rf ~/Library/Application\ Support/KTStack/
```

### 7. Delete the app

Open **Finder**, go to **Applications**, find **KTStack**, and drag it to **Trash**.

## Verifying uninstall

After uninstalling, verify that everything is removed:

### Check DNS is disabled

```bash
cat /etc/resolver/.test 2>/dev/null
```

If the file doesn't exist, DNS is cleaned up.

### Check app data is gone

```bash
ls -la ~/Library/Application\ Support/KTStack/ 2>/dev/null
```

Should show "No such file or directory".

### Check CA is untrusted

Open **Keychain Access** (Applications > Utilities) and search for "mkcert". No results means the CA is removed.

### Check shell integration is removed

Open a new Terminal window and run:

```bash
echo $PATH
```

The path should not include `/Library/Application Support/KTStack/shims/`.

## Restoring from backup before uninstall

If you have databases you want to keep, back them up before uninstalling:

1. Before uninstalling, open the **Database** section in KTStack.
2. Go to the **Backups** tab.
3. Click **Create Backup** for each connection you want to preserve.
4. The backup files are saved in `~/Library/Application Support/KTStack/backups/`.
5. You can keep these files after uninstalling and restore them to a different tool (e.g., Docker, Homebrew, a remote server).

See [09 — Database backup & restore](09-database-backup-and-restore.md) for detailed backup instructions.

## Reinstalling after uninstall

Once you've completely uninstalled KTStack, you can install it again:

1. Download the latest KTStack from [GitHub Releases](https://github.com/KTStackAPP/KTStack/releases).
2. Follow the installation steps in [01 — Install & first run](01-install-and-first-run.md).
3. On first launch, you'll go through DNS setup again.
4. Your old data is gone — create new sites and services from scratch.

If you backed up your databases, you can restore them after reinstalling. See [09 — Database backup & restore](09-database-backup-and-restore.md).

## Troubleshooting

### "Permission denied" when removing DNS resolver

You need sudo:

```bash
sudo rm -f /etc/resolver/.test
```

### DNS resolver still shows after uninstall

If `cat /etc/resolver/.test` still works after uninstall, remove it manually:

```bash
sudo rm -f /etc/resolver/.test
sudo launchctl stop com.ktstack.dnsmasq 2>/dev/null
```

### App data directory still exists

The in-app uninstall may have failed partway. Remove it manually:

```bash
rm -rf ~/Library/Application\ Support/KTStack/
```

### CA still in Keychain

Open **Keychain Access** and manually delete any certificates with "mkcert" or "KTStack" in the name.

### Shell integration lines didn't get removed

If your `.zshrc` or `.bashrc` still has KTStack paths:

```bash
nano ~/.zshrc
```

Find and delete lines containing `/KTStack/shims` or similar. Save and quit.

## Where to go next

If you're removing KTStack temporarily and planning to reinstall, bookmark [01 — Install & first run](01-install-and-first-run.md) for next time.

If you had issues during uninstall, see [18 — Troubleshooting & FAQ](18-troubleshooting-and-faq.md) for more help.

![Settings with Uninstall button](images/17-uninstall-button.png)

![Uninstall confirmation dialog](images/17-uninstall-confirmation.png)

![Uninstall log and progress](images/17-uninstall-progress.png)
