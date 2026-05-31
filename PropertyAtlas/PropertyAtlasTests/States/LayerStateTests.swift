// PropertyAtlasTests/States/LayerStateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerStateTests {
    @Test func initFromDefaultsEnablesListed() {
        let a = UUID()
        let b = UUID()
        let s = LayerState()
        s.initialize(enabledIds: [a])
        #expect(s.isEnabled(a))
        #expect(!s.isEnabled(b))
    }

    @Test func toggleFlips() {
        let a = UUID()
        let s = LayerState()
        s.initialize(enabledIds: [])
        s.toggle(a)
        #expect(s.isEnabled(a))
        s.toggle(a)
        #expect(!s.isEnabled(a))
    }

    @Test func initializeIfNeededOnlyAppliesOnce() {
        let a = UUID()
        let b = UUID()
        let s = LayerState()
        s.initializeIfNeeded(enabledIds: [a])
        s.toggle(b) // 运行时启 b
        s.initializeIfNeeded(enabledIds: [a]) // 不应覆盖
        #expect(s.isEnabled(b))
    }
}
