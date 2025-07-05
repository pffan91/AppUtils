//
//  Debouncer.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 29/03/2025.
//

import Foundation

public final class Debouncer {

    private let interval: TimeInterval
    private(set) var timer: Timer?

    public var isRunning: Bool {
        return timer?.isValid ?? false
    }

    public init(interval: TimeInterval) {
        self.interval = interval
    }

    public func cancel() {
        timer?.invalidate()
    }

    public func debounce(interval: TimeInterval? = nil, _ action: @escaping () -> Void) {
        cancel()
        timer = Timer.scheduledTimer(withTimeInterval: interval ?? self.interval, repeats: false) { _ in
            action()
        }
    }
}

public final class DispatchDebouncer {

    private let interval: TimeInterval
    private var timer: DispatchSourceTimer?

    private var isRunning = false

    public init(interval: TimeInterval) {
        self.interval = interval
    }

    deinit {
        timer?.setEventHandler(handler: nil)
        if isRunning {
            timer?.cancel()
            timer = nil
        }
    }

    public func debounce(_ action: @escaping () -> Void) {
        if isRunning {
            timer?.cancel()
        }
        timer = DispatchSource.makeTimerSource()
        timer?.setEventHandler {
            action()
        }
        timer?.schedule(deadline: .now() + interval)
        timer?.resume()
        isRunning = true
    }
}
