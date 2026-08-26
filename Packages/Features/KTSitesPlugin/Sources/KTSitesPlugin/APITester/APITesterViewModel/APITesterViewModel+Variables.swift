extension APITesterViewModel {
    func saveVariables() {
        guard !siteKey.isEmpty else { return }
        let stored = variables.map { APIVariable(name: $0.key, value: $0.value, enabled: $0.enabled) }
        APIVariableStore.save(stored, siteKey: siteKey)
    }

    func resolved(_ text: String) -> String {
        APIVariableInterpolator.resolve(text, with: variableMap())
    }

    func variableMap() -> [String: String] {
        var map: [String: String] = [:]
        for variable in variables where variable.enabled {
            let name = variable.key.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            map[name] = variable.value
        }
        return map
    }
}
