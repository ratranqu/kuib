/// Helper to convert app NamespaceSelector to namespace name string.

extension NamespaceSelector {
    /// The namespace name, or nil for all namespaces.
    var namespaceName: String? {
        switch self {
        case .all: return nil
        case .namespace(let name): return name
        }
    }
}
