//
//  DoubleTapSpaceMiddleware.swift
//  Wurstfinger
//
//  Detects two consecutive space presses within a short window and
//  rewrites the second one to ", " or ". " (configurable).
//

import Foundation

/// Replaces a trailing space with ", " or ". " when the user double-taps
/// the space key within `KeyboardConstants.SpaceGestures.doubleTapWindow`.
///
/// The middleware tracks the timestamp of the most recent `.space` action.
/// On a second `.space` within the window:
///   1. The previous space is removed via the injected `deleteBackward`.
///   2. The replacement (", " or ". ") is inserted via `insertText`.
///   3. The action is short-circuited (not forwarded), so downstream
///      middlewares (TextInputMiddleware in particular) don't insert the
///      raw space again.
///
/// Any non-space action clears the timestamp, so a tap-then-letter-then-tap
/// sequence does not trigger a replacement.
final class DoubleTapSpaceMiddleware: ActionMiddleware {
    private let now: () -> Date
    private let setting: () -> DoubleTapSpaceAction
    private let window: TimeInterval
    private let insertText: (String) -> Void
    private let deleteBackward: () -> Void

    private var lastSpaceCommittedAt: Date?

    init(
        now: @escaping () -> Date = Date.init,
        window: TimeInterval = KeyboardConstants.SpaceGestures.doubleTapWindow,
        setting: @escaping () -> DoubleTapSpaceAction,
        insertText: @escaping (String) -> Void,
        deleteBackward: @escaping () -> Void
    ) {
        self.now = now
        self.window = window
        self.setting = setting
        self.insertText = insertText
        self.deleteBackward = deleteBackward
    }

    /// Called by the view model when the user begins a space drag/slide so
    /// the next single space tap is not treated as the second tap of a pair.
    func cancelPendingTap() {
        lastSpaceCommittedAt = nil
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard case .space = context.action else {
            lastSpaceCommittedAt = nil
            next(context)
            return
        }

        guard let replacement = setting().replacement else {
            lastSpaceCommittedAt = nil
            next(context)
            return
        }

        let current = now()
        if let previous = lastSpaceCommittedAt, current.timeIntervalSince(previous) <= window {
            deleteBackward()
            insertText(replacement)
            lastSpaceCommittedAt = nil
            return
        }

        lastSpaceCommittedAt = current
        next(context)
    }
}
