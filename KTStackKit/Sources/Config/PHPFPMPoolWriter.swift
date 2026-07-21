import Foundation

public enum PHPFPMPoolWriterError: LocalizedError, Equatable {
    case invalidSendmailPath

    public var errorDescription: String? {
        switch self {
        case .invalidSendmailPath:
            "The Mailpit executable path contains a line break or null byte and cannot be written safely to PHP-FPM configuration."
        }
    }
}

public struct PHPFPMPoolWriter {
    public init() {}

    public func poolConfig(
        paths: AppSupportPaths,
        poolName: String,
        user: String = NSUserName()
    ) throws -> String {
        let socket = paths.phpFpmSocket(poolName).path
        let log = paths.phpFpmLog(poolName).path

        // PHP-FPM strips shell quotes from php_admin_value entries. A quoted Mailpit path under
        // "Application Support" therefore reaches /bin/sh as separate arguments. Backslash-escape
        // the executable path instead; it keeps the command absolute (PHP does not prefix it) and
        // preserves spaces and shell metacharacters when mail() launches Mailpit.
        let sendmailPath = try shellEscaped(paths.binary("mailpit").path)
        let sendmail = "\(sendmailPath) sendmail -S 127.0.0.1:1025"

        let mysqlSocket = paths.serviceSocket("mysql").path
        // error_log and sendmail_path use php_admin_value so a user-edited php.ini cannot redirect
        // logs or outbound mail; the mysqli socket lines stay php_value so users can override them.
        let base = """
        [global]
        error_log = \(log)
        daemonize = no
        log_limit = 8192

        [\(poolName)]
        user = \(user)
        listen = \(socket)
        listen.owner = \(user)
        listen.mode = 0660

        pm = dynamic
        pm.max_children = 5
        pm.start_servers = 2
        pm.min_spare_servers = 1
        pm.max_spare_servers = 3
        pm.max_requests = 500

        catch_workers_output = yes
        php_admin_flag[log_errors] = on
        php_admin_value[error_log] = \(log)
        php_admin_value[sendmail_path] = \(sendmail)
        php_value[mysqli.default_socket] = \(mysqlSocket)
        php_value[pdo_mysql.default_socket] = \(mysqlSocket)
        """
        let magickLines = ImageMagickEnvironment
            .sortedVariables(modulesDir: paths.phpModulesDir(version: poolName))
            .map { "env[\($0.key)] = \($0.value)" }
        guard !magickLines.isEmpty else { return base }
        return base + "\n" + magickLines.joined(separator: "\n")
    }

    @discardableResult
    public func write(paths: AppSupportPaths, poolName: String) throws -> URL {
        let url = paths.phpFpmPool(poolName)
        try poolConfig(paths: paths, poolName: poolName)
            .write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func shellEscaped(_ value: String) throws -> String {
        // Foundation percent-encodes null bytes in file URL paths (for example, as "%00").
        // Validate the decoded form so encoded control bytes cannot bypass this guard.
        let validationValue = value.removingPercentEncoding ?? value
        guard !validationValue.unicodeScalars.contains(where: { scalar in
            scalar.value == 0 || scalar.value == 10 || scalar.value == 13
        }) else {
            throw PHPFPMPoolWriterError.invalidSendmailPath
        }
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/@%_+=:,.-"))
        return value.unicodeScalars.map { scalar in
            safe.contains(scalar) ? String(scalar) : "\\\(scalar)"
        }.joined()
    }
}
