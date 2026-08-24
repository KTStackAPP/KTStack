import KTPluginKit

// Nhóm sidebar là presentation của shell; registry phẳng = flatMap các section.
struct PluginSection {
    let title: String
    let plugins: [any KTStackPlugin]
}
