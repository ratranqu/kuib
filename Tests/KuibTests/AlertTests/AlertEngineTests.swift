/// Tests for the AlertEngine.

import Testing
@testable import Alerts
@testable import Database
@testable import K8s
@testable import Models

@Suite("AlertEngine Tests")
struct AlertEngineTests {

    @Test("Default rules are loaded")
    func defaultRulesLoaded() async {
        let cache = ResourceCache()
        let db = DatabaseManager(config: DatabaseConfig(host: "localhost", port: 5432, database: "test", username: "test", password: "test"))
        let dispatcher = WebhookDispatcher(db: db)
        let engine = AlertEngine(cache: cache, db: db, dispatcher: dispatcher)

        await engine.loadDefaultRules()
        let rules = await engine.getRules()

        #expect(rules.count == 9)
        #expect(rules.contains { $0.type == .podCrashLoopBackOff })
        #expect(rules.contains { $0.type == .nodeNotReady })
    }

    @Test("Custom rule can be added and removed")
    func addRemoveCustomRule() async {
        let cache = ResourceCache()
        let db = DatabaseManager(config: DatabaseConfig(host: "localhost", port: 5432, database: "test", username: "test", password: "test"))
        let dispatcher = WebhookDispatcher(db: db)
        let engine = AlertEngine(cache: cache, db: db, dispatcher: dispatcher)

        let customRule = AlertRule(
            id: "custom-1",
            name: "Custom Rule",
            type: .custom,
            severity: .info
        )

        await engine.addRule(customRule)
        var rules = await engine.getRules()
        #expect(rules.contains { $0.id == "custom-1" })

        await engine.removeRule(id: "custom-1")
        rules = await engine.getRules()
        #expect(!rules.contains { $0.id == "custom-1" })
    }
}
