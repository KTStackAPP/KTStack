import Foundation

/// The default `php.ini` seeded for each PHP version on first use. Tuned for local development:
/// generous limits and visible errors, opcache on for the FPM workers but off for CLI.
///
/// Safety-critical, app-owned settings (error_log, sendmail_path) are NOT here — the php-fpm pool
/// injects them via `php_admin_value`, which overrides the ini, so editing this file can't redirect
/// logs or mail. Everything in this template is meant for the user to tweak.
public enum PHPIniTemplate {
    /// A complete, valid `php.ini` body. Kept deliberately small (KISS) — the common dev knobs only.
    public static let `default` = """
    ; KDWarm managed php.ini — edit freely. "Reset to default" restores this template.
    ; A .bak of the previous content is kept next to this file on every save.

    memory_limit = 512M
    upload_max_filesize = 256M
    post_max_size = 256M
    max_execution_time = 120
    max_input_time = 120
    max_input_vars = 5000

    ; Dev-friendly: surface errors in the browser. Turn display_errors Off for prod-like testing.
    display_errors = On
    display_startup_errors = On
    error_reporting = E_ALL

    date.timezone = UTC

    ; opcache speeds up repeated requests; left off for the CLI so scripts always see fresh code.
    opcache.enable = 1
    opcache.enable_cli = 0

    """
}
