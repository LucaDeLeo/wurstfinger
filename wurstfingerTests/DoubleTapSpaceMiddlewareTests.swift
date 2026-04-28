//
//  DoubleTapSpaceMiddlewareTests.swift
//  WurstfingerTests
//

import Foundation
import Testing
@testable import WurstfingerApp

struct DoubleTapSpaceMiddlewareTests {
    private final class Recorder {
        var inserts: [String] = []
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
            insertText: { recorder.inserts.append($0) },
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

        #expect(forwarded == [.space])
        #expect(recorder.deletes == 1)
        #expect(recorder.inserts == [", "])
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
        #expect(recorder.inserts.isEmpty)
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

        #expect(forwarded == [.space, .space])
        #expect(recorder.deletes == 1)
        #expect(recorder.inserts == [", "])
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
        #expect(recorder.inserts.isEmpty)
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
        #expect(recorder.inserts.isEmpty)
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
        #expect(recorder.inserts.isEmpty)
    }

    @Test func periodSettingInsertsPeriodSpace() {
        var t = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let (middleware, recorder) = makeMiddleware(mode: .period) { t }
        var forwarded: [KeyAction] = []

        runSpace(middleware, forwardedActions: &forwarded)
        t = t.addingTimeInterval(0.15)
        runSpace(middleware, forwardedActions: &forwarded)

        #expect(forwarded == [.space])
        #expect(recorder.deletes == 1)
        #expect(recorder.inserts == [". "])
    }
}
