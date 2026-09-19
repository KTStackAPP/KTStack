import AppKit

// Stub Spotlight: mở ktstack://database rồi thoát. Không link KTStackKit/Core (xem CLAUDE.md Invariants).
NSWorkspace.shared.open(
    URL(string: "ktstack://database")!,
    configuration: NSWorkspace.OpenConfiguration()
) { _, _ in
    exit(0)
}
RunLoop.current.run(until: Date().addingTimeInterval(5))
exit(0)
