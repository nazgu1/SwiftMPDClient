//
//  MPDPlayingStatus.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/01/2024.
//

import Foundation
import SwiftUI

@available(macOS 14.0, *)
@Observable
public final class MPDPlayStatus: MPDClientDelegate {
    private var client: MPDClient
    private var status: MPDStatus = .init()
    private var _queue: [MPDQueueItem] = []
    
    public var currentSong: MPDSong? {
        guard queue.count > 0, status.playingSongIndex < queue.count else {
            return nil
        }
        return queue[status.playingSongIndex].song
    }
    
    public var volume: Double {
        return status.volume
    }
    
    public var `repeat`: Bool {
        return status.repeat
    }

    public var shuffle: Bool {
        return status.random
    }
    
    public var queueLength: Int {
        return status.playlistLength
    }
    
    public var queue: [MPDQueueItem] {
        return _queue
    }
    
    public var playStatus: MPDState {
        return status.playStatus
    }
    
    public var elapsedTime: TimeInterval {
        return status.elapsed
    }

    public var totalTime: TimeInterval {
        return status.duration
    }

    public var playingSongIndex: Int {
        return status.playingSongIndex
    }
    
    public init(client: MPDClient) {
        self.client = client
        self.client.append(delegate: self)
    }
    
    // MARK: MPDClientDelegate

    public func onConnect() {
        print("MPDPlayStatus: client conected")
    }
    
    public func onDisconnect() {
        print("MPDPlayStatus: client disconected")
    }
    
    public func onRefresh(playStatus: MPDStatus, queue: [MPDQueueItem]) {
        status = playStatus
        _queue = queue
    }
}
