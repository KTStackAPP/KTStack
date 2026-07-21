# 16 — Settings & Preferences

This page walks you through KTStack's settings window, where you configure global behavior, network defaults, updates, and maintenance tasks.

## Opening Settings

1. Click the **KTStack menu-bar icon**.
2. Click the **gear icon** (⚙) in the dashboard header.
3. The Settings window opens in a tab showing all available options.

Settings are organized into four sections: **General**, **Sites & Network**, **Updates**, and **Maintenance**.

## General Settings

These options control how KTStack behaves on your Mac.

### Launch at login

**What it does**: Automatically starts KTStack when you log into macOS.

1. Toggle **Launch at login** on or off.
2. If you turn it on, macOS may ask for permission. Click **Allow**.
3. The next time you restart your Mac, KTStack launches without any action from you.

### Auto-start server

**What it does**: Automatically brings all previously running services back up when KTStack launches.

1. Toggle **Auto-start server** on or off.
2. If you turn it on, KTStack remembers which services you had running and starts them automatically next time.
3. If you turn it off, all services start stopped, and you must toggle them on manually.

### Show in menu bar

**What it does**: Displays the KTStack icon in your menu bar for quick access.

1. Toggle **Show in menu bar** on or off.
2. If you turn it off, the menu bar icon is hidden (you can still access KTStack from Finder > Applications).
3. If you turn it back on, the icon reappears.

### Monochrome menu bar icon

**What it does**: Replaces the full-color KTStack icon with a native black-and-white server symbol that follows the current macOS menu-bar appearance.

1. Toggle **Monochrome menu bar icon** on to use the server symbol.
2. Toggle it off to restore the full-color KTStack icon.
3. The icon updates immediately; KTStack does not need to restart.

## Sites & Network Settings

These options set defaults for how your sites are served.

### Sites root

**What it does**: Sets the folder where KTStack looks for your site directories.

1. Click **Choose…** next to "Sites root".
2. A file picker opens. Navigate to the folder where you keep your project folders.
3. Click **Choose** to confirm.

The default location is `~/Sites/WWW`. KTStack scans this folder for site directories when you create a new site.

### Default PHP version

**What it does**: Sets which PHP version is used for newly created sites.

1. Click the **dropdown** next to "Default PHP version".
2. Choose a PHP version from the list of installed versions (e.g., "PHP 8.3").
3. Any new site you create will use this version.

**Note**: You can still change the PHP version per site after creation. See [04 — PHP & runtimes](04-php-and-runtimes.md).

### Local TLD

**What it does**: Sets the domain suffix for all local sites (default is `.test`).

1. Click in the **Local TLD** field and edit the text (currently showing `.test`).
2. Type the new suffix without the leading dot (e.g., `local` to make sites at `https://myapp.local`).
3. Press **Return** to apply the change.
4. If you have existing sites, a confirmation dialog appears warning you that they will stop resolving until you edit them to use the new TLD.
5. Click **Change & Relaunch** to confirm. KTStack restarts to apply the change.

**Valid TLDs**: The suffix must be a valid domain label (alphanumeric and hyphens only; 2–63 characters). `.test`, `.local`, `.localhost`, and `.dev` are common choices.

**Warning**: Changing the TLD is not reversible — existing sites keep their old domains until you manually edit them. All local DNS configuration is updated, and KTStack relaunches to activate the new TLD.

### Serve over HTTPS by default

**What it does**: Automatically issues trusted local certificates for all new sites.

1. Toggle **Serve over HTTPS by default** on or off.
2. If you turn it on, all new sites are served at `https://myapp.test` with a generated certificate.
3. If you turn it off, new sites use plain HTTP (`http://myapp.test`).

**Note**: You can still toggle HTTPS per site after creation. See [05 — HTTPS & Certificates](05-https-and-certificates.md).

## Updates Settings

These options control how KTStack stays up to date.

### Automatic updates

**What it does**: Allows KTStack to download and install new versions without asking.

1. Toggle **Automatic updates** on or off.
2. If you turn it on, KTStack periodically checks for new releases and installs them in the background.
3. If you turn it off, you must manually check for updates.

### Release channel

**What it does**: Chooses which version stream to follow: stable releases or beta pre-releases.

1. Click the **dropdown** next to "Release channel".
2. Choose:
   - **Stable** — Only official releases (recommended for production use).
   - **Beta** — Pre-release versions with new features (may have bugs).
3. The current channel is shown below the dropdown (e.g., "Currently on v1.2.0").

Switching channels takes effect on the next update check.

### Check for updates

**What it does**: Immediately scans for a newer version.

1. Click **Check Now**.
2. KTStack connects to GitHub to check for new releases.
3. If an update is available, you'll see a notification. Follow the prompt to install.
4. If you're already on the latest version, you'll see a message confirming that.

## Maintenance Settings

These options manage certificates, shell integration, and app data.

### Local HTTPS Certificates

**What it does**: Manages the certificate authority (CA) that signs all your local site certificates and trusts it in your System Keychain.

1. Click **Manage…** to open the certificate settings.
2. The **Local HTTPS Certificates** sheet appears showing the current state:
   - **Not installed** — No CA exists yet. Click **Install & Trust** to create and trust one.
   - **Untrusted** — A CA exists, but your browser doesn't recognize it. Click **Trust** to add it to your Keychain.
   - **Trusted** — The CA is installed and recognized. No action needed.

3. If you click **Install & Trust** or **Trust**, macOS may ask for your admin password (required to access the System Keychain).
4. Wait for the operation to complete.

For more details, see [05 — HTTPS & Certificates](05-https-and-certificates.md).

### Terminal shell integration

**What it does**: Allows your terminal to use the same PHP and Node versions as your projects (via the `ktstack` shell shim).

1. Click **Manage…** to open the shell integration settings.
2. The **Shell Integration** sheet appears with setup instructions for your shell (Bash, Zsh, etc.).
3. Follow the printed steps to add the integration to your shell configuration file.
4. Restart your terminal and run `ktstack --version` to verify.

For more details, see [15 — Shell integration](15-shell-integration.md).

### Reset & Uninstall

**What it does**: Completely removes KTStack, all services, DNS configuration, CA trust, app data, runtimes, and databases from your Mac.

1. Click **Uninstall…** to start the uninstall process.
2. A confirmation dialog appears:
   - "Uninstall KTStack and remove all data? This stops all services and permanently deletes app data, runtimes and databases. This cannot be undone."
3. Click **Uninstall / Reset** to proceed (or **Cancel** to abort).
4. KTStack performs the following steps automatically:
   - Stops all running services
   - Removes DNS resolver configuration
   - Untrusts the local CA from your System Keychain
   - Unregisters the privileged helper
   - Deletes all app data in `~/Library/Application Support/KTStack/`
   - Removes shell integration

5. A log window shows the progress. Wait for it to complete.
6. Once done, you can safely delete the KTStack app from your Applications folder.

**Warning**: This is irreversible. All databases, project runtimes, and configuration are permanently deleted.

For complete uninstall instructions, see [17 — Uninstall & reset](17-uninstall-and-reset.md).

## Tips and notes

- **Settings are saved automatically** — Changes take effect immediately unless otherwise noted (e.g., TLD change requires relaunch).
- **Keyboard shortcuts** — Press **Cmd+,** (comma) in the dashboard to open Settings quickly.
- **Admin password** — Some settings (CA trust, DNS changes) require your admin password once. You won't be asked again for normal operations.
- **Defaults reset** — If you need to reset all settings to factory defaults, quit KTStack, run `defaults delete com.ktstack.app` in Terminal, and relaunch.

## Where to go next

Now that you understand settings, head to [17 — Uninstall & reset](17-uninstall-and-reset.md) to learn how to cleanly remove KTStack if needed. Or jump to [06 — Services](06-services.md) to manage your background services.

![Settings window with the monochrome menu bar option enabled](images/16-monochrome-menu-bar-setting.png)

![Sites & Network settings](images/16-settings-sites-network.png)

![Updates and Maintenance sections](images/16-settings-updates-maintenance.png)
