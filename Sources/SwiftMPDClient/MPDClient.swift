//
//  MPDClient.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/01/2024.
//

import Foundation

public enum MPDConnectionStatus {
    case disconnected
    case connecting
    case connected
}

public protocol MPDClientDelegate {
    func onConnect()
    func onDisconnect()
    func onRefresh(playStatus: MPDStatus, queue: [MPDQueueItem])
}

protocol MPDService {
    var status: MPDConnectionStatus { get }
    
    func connect() async throws
    func disconnect() async throws
    
    func getStatus() async throws -> MPDStatus
    func getQueue() async throws -> [MPDQueueItem]
    
    func fetchLibrary() async throws -> [MPDSong]
}

@available(macOS 14.0, *)
@Observable
public final class MPDClient: MPDService {
    private var connection = MPDConnection(host: "127.0.0.1", port: 6600)
    public var status: MPDConnectionStatus = .disconnected
    private var delegates: [MPDClientDelegate] = []
    
    var songs = [MPDSong]()
    
    public init(connection: MPDConnection = MPDConnection(host: "127.0.0.1", port: 6600), status: MPDConnectionStatus = .disconnected, delegates: [MPDClientDelegate] = [], songs: [MPDSong] = [MPDSong]()) {
        self.connection = connection
        self.status = status
        self.delegates = delegates
        self.songs = songs
    }
    
    public func append(delegate: MPDClientDelegate) {
        delegates.append(delegate)
    }
    
    public func connect() {
        guard status != .connected else {
            print("Try to connect when connected")
            return
        }
        
        status = .connecting
        Task {
            do {
                try await connection.connect()
            } catch {
                status = .disconnected
            }
            status = .connected
            _ = try? await fetchLibrary()
            try? await refresh()
        }
    }
    
    public func disconnect() {
        Task {
            await connection.disconnect()
            status = .disconnected
            
            for d in delegates {
                DispatchQueue.main.async {
                    d.onDisconnect()
                }
            }
        }
    }
    
    private func send(_ command: MPDCommand) async throws {
        guard let data = "\(command.rawValue)\n".data(using: .utf8) else {
            throw MPDError.requestMalformed
        }
        try await connection.send(data)
    }
    
    private func receive() async throws -> [String] {
        let data = try await connection.receive()
        
        guard let response = String(data: data, encoding: .utf8) else {
            throw MPDError.responseError
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
    }
    
    private func fire(command: MPDCommand) async throws {
        try await send(command)
        _ = try await receive()
    }
    
    func fetchLibrary() async throws -> [MPDSong] {
        guard status == .connected else {
            print("Try to fetchLibrary when disconnected")
            throw MPDError.notConnected
        }
        
        try await send(.search(filter: "(base '')"))
        let lines = try await receive()
            
        var songs: [MPDSong] = []
        var songDict: [String: String] = [:]

        for line in lines {
            let components = line.components(separatedBy: ": ")
            if components.count == 2 {
                if components[0] == "file", !songDict.isEmpty {
                    let song = MPDSong(
                        artist: songDict["Artist"] ?? "–",
                        album: songDict["Album"] ?? "–",
                        title: songDict["Title"] ?? "–",
                        uri: songDict["file"] ?? "–"
                    )
                    songs.append(song)
                    songDict.removeAll()
                }
                songDict[components[0]] = components[1]
            }
        }

        if let artist = songDict["Artist"], let album = songDict["Album"], let title = songDict["Title"], let uri = songDict["file"] {
            let song = MPDSong(
                artist: artist,
                album: album,
                title: title,
                uri: uri
            )
            songs.append(song)
        }
        
        self.songs = songs
        return songs
    }
    
    func getQueue() async throws -> [MPDQueueItem] {
        try await send(.playlistinfo)
        let lines = try await receive()
        
        var mpdQueue: [MPDQueueItem] = []
        var songDict: [String: String] = [:]

        for line in lines {
            let components = line.components(separatedBy: ": ")
            if components.count == 2 {
                // If the line starts a new song and we've already started one previously
                if components[0] == "file", !songDict.isEmpty,
                   let uri = songDict["file"],
                   let posString = songDict["Id"], let pos = Int(posString),
                   let idString = songDict["Pos"], let id = Int(idString)
                {
                    let song = MPDSong(
                        artist: songDict["Artist"] ?? "–",
                        album: songDict["Album"] ?? "–",
                        title: songDict["Title"] ?? "–",
                        uri: uri
                    )
                    let item = MPDQueueItem(
                        id: id,
                        pos: pos,
                        song: song
                    )
                    mpdQueue.append(item)
                    songDict.removeAll()
                }
                songDict[components[0]] = components[1]
            }
        }

        if let uri = songDict["file"],
           let posString = songDict["Id"], let pos = Int(posString),
           let idString = songDict["Pos"], let id = Int(idString)
        { // Handle the last song
            mpdQueue.append(MPDQueueItem(
                id: id,
                pos: pos,
                song: MPDSong(
                    artist: songDict["Artist"] ?? "–",
                    album: songDict["Album"] ?? "–",
                    title: songDict["Title"] ?? "–",
                    uri: uri
                )
            ))
        }

        return mpdQueue
    }
    
    func getStatus() async throws -> MPDStatus {
        try await send(.status)
        let response = try await receive()
        let lines = response.map { $0.split(separator: ": ") }
        
        let statusDict = Dictionary(uniqueKeysWithValues: lines.filter { $0.count > 1 }.map { a in (a[0], a[1]) })
        
        return MPDStatus(
            volume: Double(statusDict["volume"] ?? "0") ?? 0,
            repeat: Int(statusDict["repeat"] ?? "0") == 1,
            consume: Int(statusDict["consume"] ?? "0") == 1,
            random: Int(statusDict["random"] ?? "0") == 1,
            single: Int(statusDict["single"] ?? "0") == 1,
            crossfade: Int(statusDict["xfade"] ?? "0") ?? 0,
            playStatus: MPDState(string: String(statusDict["status"] ?? "unknown")),
            playlistLength: Int(statusDict["playlistlength"] ?? "0") ?? 0,
            playingSongIndex: Int(statusDict["song"] ?? "0") ?? 0,
            elapsed: TimeInterval(statusDict["elapsed"] ?? "0") ?? 0,
            duration: TimeInterval(statusDict["duration"] ?? "0") ?? 0
        )
    }
    
    public func refresh() async throws {
        guard status == .connected else {
            return
        }
        
        let status = try await getStatus()
        try? await Task.sleep(for: .seconds(0.2))
        let queue = try await getQueue()
        for d in delegates {
            DispatchQueue.main.async {
                d.onRefresh(playStatus: status, queue: queue)
            }
        }
    }
    
    public func addToQueue(uri: String) {
        Task {
            try? await fire(command: .addToQueue(uri: uri, position: nil))
        }
    }
    
    public func addToQueue(uris: [String]) {
        Task {
            let command: MPDCommand = .commandList(commands: uris.map { .addToQueue(uri: $0, position: nil) })
            try? await fire(command: command)
        }
    }
    
    public func clearQueue() {
        Task {
            try? await fire(command: .clear)
        }
    }
    
    public func removeFromQueue(start: Int, end: Int?) {
        Task {
            try? await fire(command: .delete(start: start, end: end))
        }
    }
    
    public func play() {
        Task {
            try? await fire(command: .play(position: nil))
        }
    }
    
    public func play(position: Int) {
        Task {
            try? await fire(command: .play(position: position))
        }
    }
    
    public func pause() {
        Task {
            try? await fire(command: .pause)
        }
    }
    
    public func next() {
        Task {
            try? await fire(command: .next)
        }
    }
    
    public func previous() {
        Task {
            try? await fire(command: .previous)
        }
    }
    
    public func setVolume(volume: Int) {
        Task {
            try? await fire(command: .setVolume(volume: volume))
        }
    }
    
    public func seek(position: TimeInterval) {
        Task {
            try? await fire(command: .seekCurrent(position: position))
        }
    }
    
    public func random(_ enabled: Bool) {
        Task {
            try? await fire(command: .random(enabled))
        }
    }
    
    public func `repeat`(_ enabled: Bool) {
        Task {
            try? await fire(command: .repeat(enabled))
        }
    }
}

@available(macOS 14.0, *)
@Observable
public final class MPDLibraryManager {
    private var client: MPDClient
    
    public var songs: [MPDSong] {
        return client.songs
    }
    
    public init(client: MPDClient) {
        self.client = client
    }
    
    public func sort(using sc: KeyPathComparator<MPDSong>) {
        client.songs.sort(using: sc)
    }
}
