import Foundation

/// Renders a self-contained `nginx.conf` plus per-site vhosts.
///
/// Two load-bearing invariants, both proven by the Foundations Spike:
///  1. Every vhost listens on the WILDCARD address `0.0.0.0:<port>`, NEVER a specific
///     interface like `127.0.0.1:80`. A non-root process can bind the wildcard privileged
///     port, but binding a specific interface returns EACCES and would need root. dnsmasq
///     still resolves `*.test → 127.0.0.1`, so the wildcard listener is reachable over
///     loopback with no privileges. `vhost(...)` enforces this; a unit test asserts it.
///  2. The config is fully self-contained — no `include fastcgi_params;` / `mime.types`
///     that would depend on files inside nginx's compiled prefix. Everything the relocated
///     binary needs is emitted inline, so it runs from any install path.
public struct NginxConfigWriter {
    /// The only address the writer will ever emit. Binding a specific interface needs root.
    public static let listenAddress = "0.0.0.0"

    public init() {}

    /// Wrap a path in double quotes for an nginx directive. The app-support tree lives under
    /// "Application Support" (contains a space), so EVERY emitted path must be quoted or nginx
    /// whitespace-splits it (`pid /…/Application Support/… → "invalid number of arguments").
    static func q(_ path: String) -> String { "\"\(path)\"" }

    /// Master `nginx.conf`. `daemon off;` is supplied by the controller via `-g`, not here.
    public func masterConfig(paths: AppSupportPaths) -> String {
        """
        worker_processes auto;
        pid \(Self.q(paths.nginxPid.path));
        error_log \(Self.q(paths.nginxErrorLog.path)) warn;

        events {
            worker_connections 1024;
        }

        http {
            access_log \(Self.q(paths.nginxAccessLog.path));
            default_type application/octet-stream;
            types {
                text/html                html htm;
                text/css                 css;
                application/javascript   js;
                application/json         json;
                image/png                png;
                image/jpeg               jpg jpeg;
                image/gif                gif;
                image/svg+xml            svg;
                image/x-icon             ico;
                font/woff2               woff2;
            }
            sendfile on;
            keepalive_timeout 65;

            include \(Self.q(paths.sitesEnabled.path + "/*.conf"));
        }
        """
    }

    /// Per-server `access_log`/`error_log` directives (empty when no paths given). Lets the Logs
    /// viewer tail one site in isolation (Phase 8).
    public static func logDirectives(access: URL?, error: URL?) -> String {
        var lines: [String] = []
        if let access { lines.append("    access_log \(q(access.path));") }
        if let error { lines.append("    error_log \(q(error.path));") }
        return lines.isEmpty ? "" : "\n" + lines.joined(separator: "\n")
    }

    /// A single PHP-serving vhost. `port` defaults to 80; the host is always the wildcard.
    public func vhost(domain: String, root: URL, phpFpmSocket: URL, port: Int = 80,
                      accessLog: URL? = nil, errorLog: URL? = nil) -> String {
        """
        server {
            listen \(Self.listenAddress):\(port);
            server_name \(domain);
            root \(Self.q(root.path));
            index index.php index.html;\(Self.logDirectives(access: accessLog, error: errorLog))

            location / {
                try_files $uri $uri/ /index.php?$query_string;
            }

            location ~ \\.php$ {
                fastcgi_pass \(Self.q("unix:" + phpFpmSocket.path));
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                fastcgi_param QUERY_STRING     $query_string;
                fastcgi_param REQUEST_METHOD   $request_method;
                fastcgi_param CONTENT_TYPE     $content_type;
                fastcgi_param CONTENT_LENGTH   $content_length;
                fastcgi_param REQUEST_URI      $request_uri;
                fastcgi_param DOCUMENT_URI     $document_uri;
                fastcgi_param DOCUMENT_ROOT    $document_root;
                fastcgi_param SERVER_PROTOCOL  $server_protocol;
                fastcgi_param GATEWAY_INTERFACE CGI/1.1;
                fastcgi_param SERVER_SOFTWARE  nginx;
                fastcgi_param REMOTE_ADDR      $remote_addr;
                fastcgi_param REMOTE_PORT      $remote_port;
                fastcgi_param SERVER_ADDR      $server_addr;
                fastcgi_param SERVER_PORT      $server_port;
                fastcgi_param SERVER_NAME      $server_name;
            }

            location ~ /\\.(?!well-known).* {
                deny all;
            }
        }
        """
    }

    /// A static vhost (plain HTML / a Node app's build output): `try_files` only, NO fastcgi —
    /// routing a non-PHP site through PHP-FPM yields 502/blank. Used for `.staticSite` and, for
    /// now, `.node` (a real `proxy_pass` to a Node port arrives in Phase 7).
    public func vhostStatic(domain: String, root: URL, port: Int = 80,
                            accessLog: URL? = nil, errorLog: URL? = nil) -> String {
        """
        server {
            listen \(Self.listenAddress):\(port);
            server_name \(domain);
            root \(Self.q(root.path));
            index index.html index.htm;\(Self.logDirectives(access: accessLog, error: errorLog))

            location / {
                try_files $uri $uri/ =404;
            }

            location ~ /\\.(?!well-known).* {
                deny all;
            }
        }
        """
    }

    public enum ConfigError: LocalizedError {
        case invalidDomain(String)
        case invalidPath(String)
        public var errorDescription: String? {
            switch self {
            case .invalidDomain(let d): return "Invalid site domain: “\(d)”."
            case .invalidPath(let p):   return "Invalid site path: “\(p)”."
            }
        }
    }

    /// A domain must be dot-separated RFC-1123 labels (each starts/ends alphanumeric, may contain
    /// hyphens). This blocks nginx directive-injection once Phase 3 lets the user type the domain
    /// (`demo.test;\n}` can't break out of `server_name`/`listen`) AND rejects shapes nginx itself
    /// would refuse — leading/trailing dots, `..`, leading/trailing hyphens.
    public static func isValidDomain(_ domain: String) -> Bool {
        let label = "[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?"
        return domain.range(of: "^\(label)(\\.\(label))+$", options: .regularExpression) != nil
    }

    /// Reject paths that could break out of the `root` directive (newlines, `;`, braces).
    public static func isSafePath(_ path: String) -> Bool {
        !path.isEmpty && path.rangeOfCharacter(from: CharacterSet(charactersIn: ";{}\n\r")) == nil
    }

    /// Write the master config + one demo vhost to disk under `paths`. Validates the domain
    /// and root path first — this writer is the substrate Phase 3 reuses for user-entered sites.
    @discardableResult
    public func writeDemo(paths: AppSupportPaths,
                          domain: String,
                          siteRoot: URL,
                          poolName: String,
                          port: Int = 80) throws -> (conf: URL, vhost: URL) {
        guard Self.isValidDomain(domain) else { throw ConfigError.invalidDomain(domain) }
        guard Self.isSafePath(siteRoot.path) else { throw ConfigError.invalidPath(siteRoot.path) }
        try masterConfig(paths: paths)
            .write(to: paths.nginxConf, atomically: true, encoding: .utf8)
        let vhostURL = paths.vhost(poolName)
        try vhost(domain: domain, root: siteRoot, phpFpmSocket: paths.phpFpmSocket(poolName), port: port)
            .write(to: vhostURL, atomically: true, encoding: .utf8)
        return (paths.nginxConf, vhostURL)
    }
}
