//
//  PausableCountdown.swift
//  AppUtils
//

import Foundation

/// A countdown that does not run while something outside the app's control is holding it up —
/// typically a human being asked to do something: solve a captcha, confirm a payment, grant a
/// permission.
///
/// The problem it solves: a deadline meant to bound how long a REQUEST may take starts bounding how
/// long a PERSON may take, and the operation dies moments after they finish. Charging their time to
/// the request's budget punishes them for being slow at a task the app itself put in front of them.
///
/// This holds the bookkeeping only. It schedules nothing and owns no timer: the caller keeps its own
/// timer and reschedules it from `remaining(at:)`. That split is deliberate — a timer cannot be
/// reasoned about in a test without waiting in real seconds, and the arithmetic is the part worth
/// reasoning about.
///
/// ```swift
/// var countdown = PausableCountdown(budgetSec: 120, now: CACurrentMediaTime())
/// // …a captcha appears
/// countdown.pause(at: CACurrentMediaTime())
/// // …the person solves it
/// countdown.resume(at: CACurrentMediaTime())
/// scheduleTimer(after: countdown.remaining(at: CACurrentMediaTime()))
/// ```
public struct PausableCountdown {

    /// Longest total pause allowed, past which the countdown runs again whether or not the thing it
    /// was waiting for is still there. Without a ceiling, a dialog nobody is looking at holds the
    /// operation open forever.
    public let maxPauseSec: TimeInterval

    private let budgetSec: TimeInterval
    private let startedAt: TimeInterval
    private var pausedAt: TimeInterval?
    private var accumulatedPause: TimeInterval = 0

    /// - Parameters:
    ///   - budgetSec: how long the operation may take, not counting pauses.
    ///   - now: a MONOTONIC reading — `CACurrentMediaTime()`, not `Date()`. System-clock changes
    ///     (timezone, NTP) would otherwise make a budget expire instantly or never.
    ///   - maxPauseSec: ceiling on total pausing. Two minutes by default, which is longer than a
    ///     person needs for a captcha and short enough that a forgotten window still resolves.
    public init(budgetSec: TimeInterval, now: TimeInterval, maxPauseSec: TimeInterval = 120) {
        self.budgetSec = budgetSec
        self.startedAt = now
        self.maxPauseSec = maxPauseSec
    }

    public var isPaused: Bool { pausedAt != nil }

    /// How much more pausing the ceiling still allows.
    ///
    /// Public because a caller that schedules a timer needs it. While paused, this type keeps
    /// answering `remaining(at:)` correctly — the budget starts running again by itself once the
    /// ceiling is passed — but nothing WAKES the caller at that moment. A caller that pauses and
    /// simply cancels its timer never finds out, and an interruption nobody closes holds the
    /// operation open forever, which is the exact failure the ceiling exists to prevent.
    ///
    /// So the timer to arm while paused is `remaining(at: now) + remainingPause`: the latest instant
    /// at which the budget could still be alive.
    public var remainingPause: TimeInterval { pauseBudgetLeft }

    /// Pausing an already-paused countdown is a no-op rather than an error: the events that trigger
    /// a pause often fire more than once for one occurrence — a page committing navigation twice,
    /// a sheet re-presenting — and counting the second one would move the pause start forward and
    /// silently charge the gap.
    public mutating func pause(at now: TimeInterval) {
        guard pausedAt == nil, pauseBudgetLeft > 0 else { return }
        pausedAt = now
    }

    /// Resuming without a pause is a no-op for the mirror-image reason: the same teardown path runs
    /// whether or not anything ever interrupted the operation.
    public mutating func resume(at now: TimeInterval) {
        guard let pausedAt else { return }
        accumulatedPause += min(max(0, now - pausedAt), pauseBudgetLeft)
        self.pausedAt = nil
    }

    /// Seconds left before the budget is spent. Zero means spent — never negative, so a caller can
    /// schedule a timer with it without checking.
    public func remaining(at now: TimeInterval) -> TimeInterval {
        max(0, budgetSec - elapsed(at: now))
    }

    /// Wall time minus the pauses, and never more than `maxPauseSec` of pausing however long the
    /// interruption stood open.
    private func elapsed(at now: TimeInterval) -> TimeInterval {
        var paused = accumulatedPause
        if let pausedAt {
            paused += min(max(0, now - pausedAt), pauseBudgetLeft)
        }
        return max(0, now - startedAt - paused)
    }

    private var pauseBudgetLeft: TimeInterval {
        max(0, maxPauseSec - accumulatedPause)
    }
}
