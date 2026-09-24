import Foundation

extension ApacheBackend {
    static let remoteIPBlock = """

    <IfFile modules/mod_remoteip.so>
        LoadModule remoteip_module modules/mod_remoteip.so
    </IfFile>
    <IfModule remoteip_module>
        RemoteIPHeader X-Real-IP
        RemoteIPInternalProxy 127.0.0.1
    </IfModule>
    """
}
