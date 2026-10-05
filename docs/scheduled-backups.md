# Scheduled Backups (`KTBackupPlugin`)

Scheduled backups copy databases, site source code (optional) and KTStack settings into a
single `.ktbackup` archive on a schedule, then deliver it to one destination per plan.

## Where it lives

| Piece | Location |
| --- | --- |
| Package | `Packages/Features/KTBackupPlugin/` (headless plugin + Settings pane) |
| Plans, destinations, run history | `~/Library/Application Support/KTStack/scheduled-backups/{plans,destinations,runs}.json` |
| Archives kept on this Mac | `…/scheduled-backups/archives/<plan name>/` |
| Log | `…/KTStack/logs/backups.log` |
| Secrets (S3 secret key, Google refresh token, custom client secret) | macOS Keychain, service `com.ktstack.backups` |

The plugin depends only on `KTStackCore`, `KTPlatformContracts` and `KTPluginKit`. The app reaches
it through three contracts:

- `ScheduledDatabaseBackupProviding` (implemented by `ManagedDatabaseBackupService` in
  `KTDatabasePlugin`) dumps the selected databases with the engine's own tools and imports a
  restored dump set into **Database › Backups**.
- `DatabaseEngineManaging` tells the runner which engines are running.
- `SiteCatalogManaging` resolves the selected sites to their folders.

## Plans

A plan has a name, a daily or weekly schedule, how many archives to keep, and its contents:

- databases (per engine, per database);
- site folders (optional), with exclude patterns such as `node_modules`, `vendor`, `.git`;
- a settings snapshot (site list, PHP and nginx configuration, shell tools, backup plans and
  app preferences; keys that look like secrets are dropped).

Each plan uploads to exactly one destination, or keeps archives on this Mac only. A plan with a
remote destination can optionally keep a local copy too.

## Scheduler

`BackupScheduler` checks every 30 seconds, after the Mac wakes and when the power source
changes. A slot missed while the Mac slept or KTStack was closed runs once at the next check
(never more than once per plan). Plans can skip runs on battery power. Quitting while a backup
runs asks for confirmation. Failed and partial runs post a notification.

## Pipeline

1. **Stage**: dumps, site folders and the settings snapshot go into `staging/<run>/` with a
   `manifest.json` (format version, contents, checksums).
2. **Archive**: the staging folder is zipped with `/usr/bin/ditto` into a `.ktbackup` file and
   its SHA-256 is computed.
3. **Deliver**: the archive is uploaded and verified (S3: every part is signed with its SHA-256
   and the archive checksum is stored as object metadata; Google Drive: size and the MD5 reported
   by Drive; local folder: re-hash of the copy before it replaces the final name).
4. **Retain**: older archives of the same plan beyond *keep last N* are moved to the trash of
   that destination (system Trash, an S3 `.trash/` prefix, Drive trash). Only files that match
   the plan's archive name pattern are ever touched.

## Destinations

| Kind | Settings | Notes |
| --- | --- | --- |
| Local folder | folder path | External drives, network shares, synced folders. |
| S3-compatible | preset, endpoint, region, bucket, prefix, access key | AWS, Cloudflare R2, Backblaze B2, MinIO, Wasabi, DigitalOcean Spaces or custom. Requests are signed with SigV4; archives over 100 MB use multipart upload. |
| Google Drive | account, folder | OAuth 2.0 for installed apps (loopback redirect + PKCE), scope `drive.file`. Resumable uploads. |

**Test Connection** writes and removes a small probe file for local folders and S3, so it proves
the credentials can upload. For Google Drive it checks the account and that the folder exists.

## Restore

**More › Restore…** on a plan lists that plan's archives at its destination (or on this Mac),
downloads one, verifies its checksum and then:

- adds each database dump set to **Database › Backups**, where you restore it into a server;
- copies site folders and the settings snapshot into `~/Downloads/KTStack Restore <date>/`.

Nothing in place is overwritten.

## Google Drive setup

Release builds inject the Google credentials through build settings, which land in `Info.plist`:

| Build setting | Info.plist key | Used for |
| --- | --- | --- |
| `KT_GOOGLE_OAUTH_CLIENT_ID` | `KTGoogleOAuthClientID` | Sign-in (Desktop app OAuth client) |
| `KT_GOOGLE_OAUTH_CLIENT_SECRET` | `KTGoogleOAuthClientSecret` | Token exchange (not confidential for desktop clients) |
| `KT_GOOGLE_PICKER_API_KEY` | `KTGooglePickerAPIKey` | Google Picker |
| `KT_GOOGLE_PROJECT_NUMBER` | `KTGoogleProjectNumber` | Google Picker app ID |

Leave them empty and the bundled Google app is hidden; each destination can still use its own
OAuth client ID and secret.

To create the credentials:

1. In Google Cloud, enable the **Google Drive API** and the **Google Picker API**.
2. Configure the OAuth consent screen with the `.../auth/drive.file` scope only.
3. Create an OAuth client of type **Desktop app**.
4. Create an API key restricted to the Picker API, with the HTTP referrer
   `http://127.0.0.1:53683/*`.

### Folder picker

With `drive.file`, KTStack can only see files and folders it created or that the user picked.

- **Browse…** lists folders KTStack created and can create new ones.
- **Pick Existing Folder…** opens Google Picker in the browser. KTStack serves a one-shot page
  from `http://127.0.0.1:53683/` with a random nonce, the page shows a folders-only Picker
  and sends the chosen folder back to the same local server. Picking a folder grants
  `drive.file` access to it. The button is hidden when the Picker key or project number is
  missing.

The Picker is the only way to back up into an existing folder without asking for the much broader
`drive` scope. The fixed port is needed because Picker API keys are restricted by referrer.

## Tests

`swift test` in `Packages/Features/KTBackupPlugin` covers schedule maths, the trigger policy,
retention, the archive naming and manifest, exclude matching, the settings snapshot, the S3
signer and client, the Google token flow, Drive client and loopback server,
and an end-to-end local backup followed by a restore.
