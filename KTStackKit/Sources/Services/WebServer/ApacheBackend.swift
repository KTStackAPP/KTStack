import Foundation

// Standalone Apache config for one PHP site's loopback backend. Plain HTTP on 127.0.0.1:<port>,
// PHP via mod_proxy_fcgi to the existing PHP-FPM unix socket (never mod_php, never mod_ssl: the
// front terminates TLS). SERVER_PORT/HTTPS are pinned from the front-terminated state via
// UseCanonicalName + ServerName, so framework redirect URLs are not built from the loopback port.
//
// ServerRoot points at the on-demand relocated Apache install; modules load from <root>/modules.
public struct ApacheBackend: WebServerBackend {
    public let engine: WebServerEngine = .apache

    private let serverRoot: URL

    public init(serverRoot: URL) {
        self.serverRoot = serverRoot
    }

    public func backendConfig(context: BackendRenderContext) -> String {
        let q = NginxConfigWriter.q
        let serverPort = context.secure ? 443 : 80
        let httpsEnv = context.secure ? "\n    SetEnv HTTPS on" : ""
        let handler = "proxy:unix:\(context.phpFpmSocket.path)|fcgi://localhost/"
        return """
        ServerRoot \(q(serverRoot.path))
        PidFile \(q(context.pidFile.path))
        Listen 127.0.0.1:\(context.backendPort)
        ServerName \(context.domain)
        UseCanonicalName On
        UseCanonicalPhysicalPort Off
        TypesConfig \(q(serverRoot.appendingPathComponent("conf/mime.types").path))

        \(Self.loadModules)

        ErrorLog \(q(context.errorLog.path))
        CustomLog \(q(context.accessLog.path)) common

        <VirtualHost 127.0.0.1:\(context.backendPort)>
            ServerName \(context.domain):\(serverPort)
            DocumentRoot \(q(context.root.path))\(httpsEnv)

            <Directory \(q(context.root.path))>
                Options Indexes FollowSymLinks
                AllowOverride All
                Require all granted
                # Front-controller routing: send any non-file URL to index.php, matching the
                # nginx backend's `try_files $uri $uri/ /index.php`. Without this, pretty URLs
                # (WordPress permalinks, Laravel routes) 404 unless a .htaccess does the rewrite.
                FallbackResource /index.php
            </Directory>
            DirectoryIndex index.php index.html

            <FilesMatch "\\.php$">
                SetHandler \(q(handler))
            </FilesMatch>

            <FilesMatch "^\\.(?!well-known)">
                Require all denied
            </FilesMatch>
        </VirtualHost>
        """
    }

    // mod_proxy + mod_proxy_fcgi for PHP-FPM. The rest matches a typical shared-hosting Apache so
    // real-world .htaccess and caching plugins behave the same locally: rewrite/headers/alias,
    // expires + deflate/filter (browser cache + gzip), access_compat (old `Order allow,deny`
    // syntax → 500 without it), authz_host, negotiation/autoindex. KEEP IN SYNC with the MODULES
    // list in scripts/build-apache-relocatable.sh (the tarball must ship every .so loaded here).
    static let loadModules = """
    LoadModule mpm_event_module modules/mod_mpm_event.so
    LoadModule authz_core_module modules/mod_authz_core.so
    LoadModule authz_host_module modules/mod_authz_host.so
    LoadModule access_compat_module modules/mod_access_compat.so
    LoadModule unixd_module modules/mod_unixd.so
    LoadModule log_config_module modules/mod_log_config.so
    LoadModule mime_module modules/mod_mime.so
    LoadModule dir_module modules/mod_dir.so
    LoadModule autoindex_module modules/mod_autoindex.so
    LoadModule negotiation_module modules/mod_negotiation.so
    LoadModule env_module modules/mod_env.so
    LoadModule setenvif_module modules/mod_setenvif.so
    LoadModule filter_module modules/mod_filter.so
    LoadModule deflate_module modules/mod_deflate.so
    LoadModule expires_module modules/mod_expires.so
    LoadModule headers_module modules/mod_headers.so
    LoadModule alias_module modules/mod_alias.so
    LoadModule rewrite_module modules/mod_rewrite.so
    LoadModule proxy_module modules/mod_proxy.so
    LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
    """
}
