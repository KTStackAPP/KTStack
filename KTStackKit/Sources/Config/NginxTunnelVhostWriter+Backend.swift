import Foundation

extension NginxTunnelVhostWriter {
    func backendProxyServer(port: Int, backendPort: Int, host: String, logs: String, clearEncoding: Bool) -> String {
        let encoding = clearEncoding ? "\n            proxy_set_header Accept-Encoding \"\";" : ""
        return """
        server {
            listen \(Self.listenAddress):\(port);
            server_name _;\(logs)

            location / {
                proxy_pass http://127.0.0.1:\(backendPort);
                proxy_http_version 1.1;
                proxy_set_header Host \(host);
                proxy_set_header X-Forwarded-Host \(host);
                proxy_set_header X-Forwarded-Proto https;
                proxy_set_header X-Forwarded-Port 443;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\(encoding)
                proxy_read_timeout 300;
            }
        }
        """
    }
}
