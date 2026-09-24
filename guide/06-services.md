# 06 — Services

This page covers KTStack's background services: what they are, how to start and stop them, how to install optional ones, and what to do when something goes wrong.

## What are services?

Services are long-running background processes that power your local environment. KTStack manages each one for you — you don't have to install or run them manually.

| Service | Purpose | Default |
|---------|---------|---------|
| **Nginx** | Web server and reverse proxy (routes requests to PHP-FPM or Node) | Always installed |
| **PHP-FPM** | PHP application server | Always installed |
| **dnsmasq** | Local DNS server (resolves `*.test` domains) | Always installed |
| **MySQL** | Relational database | Optional (install on demand) |
| **PostgreSQL** | Relational database | Optional (install on demand) |
| **Redis** | In-memory cache and message broker | Optional (install on demand) |
| **MongoDB** | Document database | Optional (install on demand) |
| **Mailpit** | Email testing inbox (captures outgoing mail) | Always installed |

The first three (Nginx, PHP-FPM, dnsmasq) are core to KTStack and are pre-installed. The others are optional and only take up disk space when you install them.

## Opening the Services section

1. Click the KTStack menu-bar icon.
2. Click **Services** or press the Services tab in the dashboard.

You'll see services grouped by category:
- **Core Proxy & DNS**: Nginx and dnsmasq.
- **Runtimes**: PHP-FPM.
- **Databases & Cache**: MySQL, PostgreSQL, Redis, MongoDB, and Mailpit.

Each service shows:
- A **status dot** (green = running, gray = stopped, yellow = warning).
- The service's **name** and optional **details** (like database version or port).
- A **toggle** to start/stop it.
- A **restart button** (circular arrow icon).

## Starting and stopping services

### Toggle a single service

1. Find the service in the Services section.
2. Click the **toggle** on the right side of the row.
3. **Green dot**: The service is starting or is already running.
4. **Gray dot**: The service is stopped or is stopping.

Starting a service usually takes a few seconds. Stopping it is instant.

### Start all services at once

Click the **Start All** button at the top of the Services section. All installed services will start. You'll see a toast notification ("Starting all services") at the bottom of the screen.

### Restart a single service

Click the **restart button** (circular arrow icon) next to the service. This is useful if a service is misbehaving or you edited its config and want to reload it.

### Restart all services at once

Click the **Restart All** button at the top of the Services section. All services will be stopped and restarted. This takes a few seconds and is useful for debugging or after system changes.

## Service status indicators

Each service shows a status dot and a label:

| Dot | Label | Meaning |
|-----|-------|---------|
| 🟢 Green | Running | Service is active and healthy. |
| ⚫ Gray | Stopped | Service is off. Click the toggle to start it. |
| 🟡 Yellow | Warning | Service is running but reporting a minor issue (e.g., low disk space). |
| 🔴 Red | Error | Service crashed or failed to start. Check the logs for details. |
| ⏳ Hourglass | Installing | A new service is being downloaded and installed. |

## Installing optional services

Databases and cache services are not installed by default to save disk space.

### Install a service for the first time

1. Find the service in the Services section (e.g., MySQL, Redis).
2. If it shows an **Install** button, click it.
3. A progress bar appears showing the download and installation.
4. Once complete, the service is installed and stopped. The toggle becomes active.
5. Click the toggle to start the service.

Installation takes a minute or two per service, depending on your internet speed and the service size.

### Cancel an installation

If an installation is taking too long, click the **X** button next to the progress bar to cancel it.

## Restarting individual services

Click the **restart button** (circular arrow) next to a service to stop and start it immediately. This is useful if:

- You edited the service's config file manually and want to reload it.
- The service is not responding and you want to reset it.
- You made a change to your site and need PHP or the web server to pick it up.

Restarting takes a few seconds. Requests to your sites may fail during the restart — wait a moment and refresh.

## Viewing service logs

To debug a service that's not working, you can view its logs:

1. Find the service in the Services section.
2. Click the **logs button** (if visible) or the **restart button** and then find a "View Logs" option in the menu.
3. The Logs section opens showing real-time output from that service.

For more on logs, see [11 — Logs & dumps](11-logs-and-dumps.md).

## Resetting service data

If a database service is corrupted or you want to start with a clean slate, you can reset it:

1. Find the service (e.g., MySQL, PostgreSQL, MongoDB).
2. Click the **menu button** (three dots, if visible) or right-click the row.
3. Select **Reset Data** or similar.
4. A confirmation dialog appears: "Reset [Service] data? This permanently deletes [Service]'s stored data, then restarts it from an empty datastore."
5. Click **Reset [Service] data** to confirm.

**Warning**: This is destructive. All databases, tables, and data in that service are deleted. This cannot be undone.

After reset, the service restarts empty. You'll need to recreate any databases you had.

## Status banners and warnings

At the top of the Services section, you may see colored banners warning about issues:

| Banner | Meaning | Action |
|--------|---------|--------|
| 🔴 CA not trusted | The HTTPS certificate authority is not installed in your System Keychain. | Click **Manage** to go to Settings and trust the CA. |
| 🔴 DNS not enabled | The dnsmasq DNS service is off or port 53 is in use by another service. | Click **Enable DNS** or **Reset** to troubleshoot. |
| 🟡 Port conflict | A port that KTStack wants to use (e.g., 443 for HTTPS, 3306 for MySQL) is already in use by another app. | Click **Restart** to try to recover, or stop the conflicting app. |

## Common tasks

### Check if services are running

Look at the Services section. Services with a green dot are running. If you see a lot of gray dots, click **Start All** to get everything going.

### Restart the whole environment

Click **Restart All** at the top of the Services section. All services stop and start again. This is useful after rebooting your Mac or if something feels stuck.

### Find out why a service won't start

1. Find the service in the Services section.
2. Click the toggle to try starting it.
3. If it fails, look for a **red dot** and an **Error** label.
4. Click the service row to see the error message, or open the Logs section to see detailed output.

### Save space by uninstalling a database

If you installed a database version you no longer use, you can uninstall it from **Runtimes**:

1. Stop the service (toggle off). Uninstall is refused while the engine is running or still loaded.
2. Open the engine in **Runtimes**, expand the version and click **Uninstall…**.
3. The confirmation shows where that version's data lives and how big it is.
4. The binaries are removed. The data is **kept**: it moves to `data/[service-name]/.removed/[version]-[timestamp]` and is listed under **Kept data**.

After reinstalling that version, click **Restore** on its kept data to move it back into place. To free the space, click **Delete data…** and confirm twice; the folder goes to the Trash.

## Tips and notes

- **Service startup order**: KTStack starts services in the right order. You don't need to worry about dependencies.
- **Auto-start**: KTStack remembers which services you had running and tries to start them automatically on next launch.
- **Ports**: Each service listens on a default port (e.g., MySQL on 3306, PostgreSQL on 5432, Redis on 6379). You can change these in Settings if you have conflicts.
- **Storage**: Database services store their data in `~/Library/Application Support/KTStack/data/[service-name]/`. You can move or back up these folders.
- **Logs**: All service logs are stored in `~/Library/Application Support/KTStack/logs/`. View them in the **Logs** section or in Finder.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Service won't start | Check the banner at the top for a port conflict or DNS issue. Open Logs to see the error. |
| "Address already in use" error | Another app is using the same port. Run `lsof -i :[port]` in Terminal to find it, then stop it or change KTStack's port in Settings. |
| Service is stuck on "Installing" | Cancel the installation and try again. Check your internet connection. |
| "Permission denied" when starting a service | Some services (like dnsmasq) need elevated permissions. Make sure you've completed the DNS setup in [01 — Install & first run](01-install-and-first-run.md). |
| Database is corrupted or has weird errors | Stop the service, reset its data (warning: this deletes everything), and restart. See [Resetting service data](#resetting-service-data) above. |

## Where to go next

Now that services are running, head to [07 — Database basics](07-database-basics.md) to connect to your databases and create tables. Or jump to [10 — Email testing with Mailpit](10-email-testing-mailpit.md) to test outgoing mail.
