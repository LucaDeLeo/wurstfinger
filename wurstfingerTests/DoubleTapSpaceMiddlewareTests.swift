//
//  DoubleTapSpaceMiddlewareTests.swift
//  WurstfingerTests
//

import Foundation
import Testing
@testable import WurstfingerApp

struct DoubleTapSpaceMiddlewareTests {
    private final class Recorder {
        var deletes = 0
    }

    private func makeMiddleware(
        mode: DoubleTapSpaceAction,
        clock: @escaping () -> Date
    ) -> (DoubleTapSpaceMiddleware, Recorder) {
        let recorder = Recorder()
        let middleware = DoubleTapSpaceMiddleware(
            now: clock,
            window: 0.3,
            setting: { mode },
            deleteBackward: { recorder.deletes += 1 }
        )
        return (middleware, recorder)
    }

    private func runSpace(
        _ middleware: DoubleTapSpaceMiddleware,
        forwardedActions: inout [KeyAction]
    ) {
        let context = ActionContext(action: .space, binding: nil, mode: ModeNames.main)
        middleware.process(context) { ctx in
            forwardedActions.append(ctx.action)
        }
    }

    @Test func doubleTapWithinWindowReplacesWithComma() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .comma) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.15)
        runSpace(middleware, forwardedActions: &forwarded)

        // The second tap must delete the pending space and forward the
        // replacement as .commitText so downstream middlewares (text input,
        // auto-capitalization) observe the mutation.
        #expect(forwarded == [.space, .commitText(", ")])
        #expect(recorder.deletes == 1)
    }

    @Test func secondTapOutsideWindowOnlyForwards() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .comma) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.5)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space, .space])
        #expect(recorder.deletes == 0)
    }

    @Test func tripleTapDoesNotChainReplacement() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .comma) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.10)
        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.10)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space, .commitText(", "), .space])
        #expect(recorder.deletes == 1)
    }

    @Test func cancelPendingTapPreventsReplacement() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .comma) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        middleware.cancelPendingTap()
        t = t.addingTimeInterval(0.10)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space, .space])
        #expect(recorder.deletes == 0)
    }

    @Test func nonSpaceActionResetsTimer() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .comma) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        let letter = ActionContext(action: .commitText("a"), binding: nil, mode: ModeNames.main)
        middleware.process(letter) { ctx in forwarded.append(ctx.action) }
        t = t.addingTimeInterval(0.10)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space, .commitText("a"), .space])
        #expect(recorder.deletes == 0)
    }

    @Test func offSettingNeverReplaces() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .off) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.05)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space, .space])
        #expect(recorder.deletes == 0)
    }

    @Test func periodSettingInsertsPeriodSpace() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .period) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.15)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space, .commitText(". ")])
        #expect(recorder.deletes == 1)
    }
}

// MARK: - Pipeline integration

struct DoubleTapSpacePipelineTests {
    /// Regression: the second tap used to short-circuit the pipeline, so
    /// `AutoCapitalizationMiddleware` never saw the ". " and the next letter
    /// stayed lowercase — unlike a manually typed period.
    @Test func doubleTapPeriodEngagesAutoCapitalization() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        vm.sharedDefaults.set(true, forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
        vm.sharedDefaults.set(
            DoubleTapSpaceAction.period.rawValue,
            forKey: SettingsKey.doubleTapSpaceAction.rawValue
        )
        target.documentContextBeforeInput = "Hallo"

        // Two synchronous dispatches land far inside the 0.3s window.
        vm.dispatchAction(.space)
        vm.dispatchAction(.space)

        #expect(target.documentContextBeforeInput == "Hallo. ")
        #expect(vm.activeModeName == ModeNames.shifted)
        #expect(vm.shiftEngagedByAutoCapitalization)
    }

    @Test func doubleTapCommaDoesNotEngageAutoCapitalization() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        vm.sharedDefaults.set(true, forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
        vm.sharedDefaults.set(
            DoubleTapSpaceAction.comma.rawValue,
            forKey: SettingsKey.doubleTapSpaceAction.rawValue
        )
        target.documentContextBeforeInput = "Hallo"

        vm.dispatchAction(.space)
        vm.dispatchAction(.space)

        #expect(target.documentContextBeforeInput == "Hallo, ")
        #expect(vm.activeModeName == ModeNames.main)
    }
}
