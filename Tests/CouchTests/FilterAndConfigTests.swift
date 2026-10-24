import Testing
@testable import Couch

@Suite struct AppFilterTests {
    @Test func allowlistAllowsListedAppsOnly() {
        let f = AppFilter(mode: .allowlist, apps: ["com.colliderli.iina"])
        #expect(f.allows("com.colliderli.iina"))
        #expect(!f.allows("com.valvesoftware.steam"))
        #expect(!f.allows(nil))
    }

    @Test func offModeAllowsEverything() {
        let f = AppFilter(mode: .off, apps: [])
        #expect(f.allows("any.game"))
        #expect(f.allows(nil))
    }

    @Test func cleanedDropsBlanksAndDuplicatesKeepingOrder() {
        let f = AppFilter(mode: .allowlist, apps: [" a ", "", "b", "a", "  "]).cleaned()
        #expect(f.apps == ["a", "b"])
    }

    @Test func defaultsContainIINAAndAreUnique() {
        #expect(AppFilter.defaults.allows("com.colliderli.iina"))
        #expect(Set(AppFilter.defaultApps).count == AppFilter.defaultApps.count)
    }
}

@Suite struct ConfigValidationTests {
    @Test func defaultsAreValid() {
        let (v, warnings) = Config.validate(Config.defaults)
        #expect(v == Config.defaults)
        #expect(warnings.isEmpty)
    }

    @Test func badThresholdFallsBackToDefault() {
        var v = Config.defaults
        v.triggerThreshold = 1.0
        let (fixed, warnings) = Config.validate(v)
        #expect(fixed.triggerThreshold == Config.defaults.triggerThreshold)
        #expect(!warnings.isEmpty)
    }

    @Test func invertedSeekIntervalsFallBack() {
        var v = Config.defaults
        v.seekFast = 1.0
        v.seekSlow = 0.5
        let (fixed, _) = Config.validate(v)
        #expect(fixed.seekSlow == Config.defaults.seekSlow)
        #expect(fixed.seekFast == Config.defaults.seekFast)
    }

    @Test func emptyAllowlistWarnsButIsKept() {
        var v = Config.defaults
        v.appFilter = AppFilter(mode: .allowlist, apps: [])
        let (fixed, warnings) = Config.validate(v)
        #expect(fixed.appFilter.apps.isEmpty)
        #expect(warnings.contains { $0.contains("allowlist is empty") })
    }
}
