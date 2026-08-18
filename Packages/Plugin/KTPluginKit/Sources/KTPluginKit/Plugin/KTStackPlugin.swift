import SwiftUI

// Contract lõi tối thiểu; mọi capability khác là protocol riêng plugin opt-in bằng conformance.
public protocol KTStackPlugin: AnyObject {
    var descriptor: PluginDescriptor { get }
    @MainActor func makeContentView() -> AnyView
}
