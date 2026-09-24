import Foundation

extension DatabaseViewModel {
    func deselectAndWait() async {
        let previous = driver
        deselect()
        await previous?.closeSession()
    }
}
