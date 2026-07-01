import Foundation

public enum NginxUserIncludeTemplate {
    public static let `default` = """
    # KTStack managed nginx user include
    # -----------------------------------------------------------------------
    # This file is included inside the http{} block of the generated nginx.conf,
    # BEFORE all server{} blocks. It survives site list regeneration — KTStack
    # never overwrites or deletes this file.
    #
    # Every save runs `nginx -t` and reverts on failure. The path shown in any
    # error output tells you whether the problem is in this file or a generated
    # vhost under sites-enabled/.
    #
    # WARNING: Do NOT repeat directives already set by KTStack in the http{} block.
    # These are single-occurrence directives and a duplicate causes a FATAL nginx -t
    # error that blocks all reloads until removed:
    #   client_max_body_size, keepalive_timeout, sendfile, access_log, default_type
    #
    # -----------------------------------------------------------------------
    # EXAMPLES (remove the # prefix to activate a directive)
    # -----------------------------------------------------------------------
    #
    # -- gzip compression ------------------------------------------------
    # gzip on;
    # gzip_types text/plain text/css application/javascript application/json
    #            image/svg+xml application/xml;
    # gzip_vary on;
    # gzip_min_length 1024;
    #
    # -- security headers (applied to all server blocks below) -----------
    # add_header X-Content-Type-Options "nosniff" always;
    # add_header X-Frame-Options "SAMEORIGIN" always;
    # add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    #
    # -- real IP (reverse-proxy setups: replace 10.0.0.0/8 as needed) ---
    # set_real_ip_from 10.0.0.0/8;
    # real_ip_header X-Forwarded-For;
    # real_ip_recursive on;
    #
    # -- proxy buffering (increase for large upstream responses) ---------
    # proxy_buffers 16 4k;
    # proxy_buffer_size 8k;
    #
    """
}
