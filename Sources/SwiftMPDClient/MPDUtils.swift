//
//  Semaphore.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/02/2024.
//

import Foundation

@available(macOS 10.15, *)
@available(iOS 13.0, *)
actor Semaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(count: Int = 0) {
        self.count = count
    }

    func wait() async {
        count -= 1
        if count >= 0 { return }
        await withCheckedContinuation {
            waiters.append($0)
        }
    }

    func release(count: Int = 1) {
        assert(count >= 1)
        self.count += count
        for _ in 0 ..< count {
            if waiters.isEmpty { return }
            waiters.removeFirst().resume()
        }
    }
}

// MARK: - MPDError

enum MPDError: Error {
    case notConnected
    case requestMalformed
    case receiveFailed
    case responseError
}

// MARK: - MPDStatus

public struct MPDStatus {
    var volume: Double = 0
    var `repeat`: Bool = false
    var consume: Bool = false
    var random: Bool = false
    var single: Bool = false
    var crossfade: Int = 0
    var playStatus: MPDState = .unknown

    var playlistVersion: Int = -1
    var playlistLength: Int = 0

    var playingSongIndex: Int = -1

    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 0
}
