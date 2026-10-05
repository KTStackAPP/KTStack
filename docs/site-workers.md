# Site Workers

Site workers are long-lived commands that KTStack runs and supervises for a PHP site, such as
`php artisan queue:work` and `php artisan schedule:work` (issue #105).

## Where it lives

| Piece | Location |
| --- | --- |
| Model, command splitter, validation, presets | `KTStackCore/Sites/SiteWorker*.swift` |
| Supervisor process (`kt worker-supervise`) | `KTStackCore/Process/WorkerSupervisor*.swift`, `WorkerBackoff.swift`, `WorkerStatus.swift` |
| launchd jobs, reconcile, status | `KTStackKit/Sources/Services/Workers/` |
| Contract | `KTPlatformContracts/SiteWorkerContracts.swift` (`SiteWorkerManaging`) |
| UI | `KTSitesPlugin/Views/SiteWorkers/`, `SiteWorkersModel.swift`, `SitesViewModel+Workers.swift` |
| IPC / CLI / MCP | `KTIPCCommandDispatcher+Workers.swift`, `KTCLI/Commands/WorkersCommand.swift`, `KTMCPToolCatalog` |
| Definitions | `Site.workers` in `config/sites/sites.json` (`name`, `command`, `enabled`) |
| Logs | `logs/sites/<domain>.worker-<name>.log` (rotated by `LogRotator`) |
| Status and spec fingerprints | `run/workers/<label>.json`, `run/workers/<label>.spec.json` |

## Lifecycle

- A worker is **enabled** when the user presses Start and disabled by Stop. New workers and presets
  start disabled, so nothing runs until the user asks for it.
- Enabled workers run **while the server runs**. `LocalServerController` calls
  `SiteWorkerSupervisor.reconcile(sites:)` at the end of `applyConfiguration` (server start,
  restart, every registry change while running), after `startNginx`/`restartNginx`, and in
  `reattachOnLaunch`. `stop`, `stopNginx`, `restart` and failed starts call `stopAll()`.
  `shutdownForQuit` boots out every `com.ktstack.*` label, workers included.
- Only PHP sites with a folder (`Site.supportsWorkers`) run workers.

## launchd job

Each enabled worker is a launchd user agent labelled
`com.ktstack.worker.<site uuid>.<worker uuid>`:

```
<app>/Contents/MacOS/kt worker-supervise --parent-pid <app pid> --status run/workers/<label>.json \
    -- <php binary> -c config/php/<v>/php.ini artisan queue:work …
```

- A leading `php` token is replaced by the site's effective PHP binary and `php.ini`. Other
  commands run as typed; the supervisor resolves a bare name through `PATH` and a relative path
  against the site folder.
- `WorkingDirectory` is the site folder. The environment is the site's env vars plus `PATH`
  (site PHP `bin`, KTStack shims, system paths), `HOME`, `PHPRC`, `PHP_INI_SCAN_DIR` and the
  ImageMagick variables, matching the terminal shims.
- stdout and stderr go to the worker log file, which the Logs plugin lists as
  `site-<domain>-worker-<name>`.
- `KeepAlive = {SuccessfulExit: false}`: launchd only restarts the supervisor itself if it dies.
- Jobs are torn down **by label**, never by binary path, because every worker shares the PHP binary.
- `reconcile` compares a fingerprint of the spec (arguments, environment, folder, log) with the
  one written at bootstrap. A changed command, PHP version, env var or app pid reloads the job;
  an unchanged one is left alone.

## Supervisor and restart policy

`kt worker-supervise` runs the command as a child and restarts it according to `WorkerBackoff`:

- A run shorter than 60 s is a quick exit. Quick exits wait 1 s, 2 s, 4 s … up to 60 s before
  the next start. A run of 60 s or more resets the count and restarts after 1 s (this covers
  `queue:work --max-time` and `--max-jobs`, which exit 0 on purpose).
- After 8 quick exits in a row the supervisor writes `crashed` and exits 0, so launchd does not
  start it again. **Restart** (`launchctl kickstart -k`) starts a fresh supervisor.
- SIGTERM (bootout, Stop, server stop, quit) is forwarded to the child, which gets 10 s to finish
  its current job before SIGKILL.
- The supervisor polls the app pid and stops the child when KTStack is gone, so a crashed app
  never leaves workers behind. The next launch reloads the jobs because the parent pid in the
  fingerprint changed.

The status file holds `running`, `backoff` (with the next attempt time), `crashed` or `stopped`,
the restart count and the last exit status. `SiteWorkerSupervisor.statuses` maps it, together with
the enabled flag and whether the server and the job are up, to `SiteWorkerRunState`
(`stopped`, `waitingForServer`, `starting`, `running`, `backoff`, `crashed`).
`LocalServerController.workersStateStream()` polls it every 2 s off the main actor while the
Sites section is visible.

## Interfaces

- **UI**: Site Settings → Workers (add, edit, remove, Laravel presets, start, stop, restart, logs).
  Cards and rows show a worker badge.
- **IPC**: `workers.list` (`site` optional), `workers.start`, `workers.stop`, `workers.restart`
  (`site`, `worker`). The site is matched by domain or name, the worker by name.
- **CLI**: `kt workers [list] [site] [--json]`, `kt workers start|stop|restart <site> <worker>`.
- **MCP**: `ktstack_list_workers`, `ktstack_start_worker`, `ktstack_stop_worker`.

## Limits

- Worker names: 1–32 lowercase letters, digits or dashes, unique per site.
- Commands: at most 1024 characters, no control characters, balanced quotes. Words are split like
  a shell (quotes and backslashes) but nothing is expanded; there is no shell.
- At most 10 workers per site.
