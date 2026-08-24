// Route enum plugin sở hữu: App map sang selection id của sidebar. Remedy .openLoginItems xử lý
// trong plugin (SMAppService), không đi qua route.
public enum DoctorRoute: Sendable {
    case services, settings, runtimes
}
