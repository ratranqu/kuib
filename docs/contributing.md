# Contributing Guide

## Development Setup

1. Clone the repo and follow [Getting Started](getting-started.md)
2. Run `swift build` to verify compilation
3. Run `swift test --filter KuibTests` to verify tests pass

## Code Style

- Follow Swift API Design Guidelines
- Use `///` doc comments on all public types, methods, and properties
- Prefer actors for shared mutable state
- Use `async/await` throughout — no completion handlers
- Keep files focused: one major type per file

## Project Conventions

### Modules
- **Models** — No dependencies. Pure value types.
- **K8s** — Depends on Models only (plus SwiftkubeClient for the production impl)
- **Database** — Depends on Models only (plus PostgresNIO)
- **Alerts** — Depends on K8s, Database, Models
- **Pages** — Depends on Components, Models
- **Components** — Depends on Models only
- **Server** — Depends on everything (routes wire it all together)
- **App** — Entry point, depends on everything

### Adding a New Resource Type

1. Add the model to `Sources/Models/ResourceState.swift`
2. Add list/get methods to `K8sClientProtocol`
3. Implement in `SwiftkubeK8sClient` with model conversion
4. Add to `MockK8sClient`
5. Add cache methods to `ResourceCache`
6. Add watcher in `ResourceWatcher`
7. Create page in `Sources/Pages/`
8. Register routes in `PageRoutes.swift`
9. Add test fixtures to `TestFixtures.swift`
10. Add tests

### Adding a New Alert Rule

1. Add the rule type to `AlertRuleType` enum in `AlertModels.swift`
2. Add evaluation logic in `AlertEngine.evaluateRule()`
3. Add to default rules in `loadDefaultRules()`
4. Add tests in `AlertEngineTests.swift`

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commits
3. Ensure `swift test` passes
4. Update documentation if adding features
5. Submit a PR with a description of what and why

## Testing Requirements

- All new code must have unit tests
- Use `MockK8sClient` for testing K8s interactions
- Test HTML rendering by asserting on rendered string content
- Integration tests are optional but appreciated
