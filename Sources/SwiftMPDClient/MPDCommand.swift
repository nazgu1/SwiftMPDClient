//
//  MPDCommand.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 19/02/2024.
//

import Foundation

enum MPDCommand: RawRepresentable {
    init?(rawValue: String) {
        switch rawValue {
        case "next": self = .next
        case "pause": self = .pause
        case "playlistinfo": self = .playlistinfo
        case "previous": self = .previous
        case "status": self = .status
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .commandList(let commands):
            return """
            command_list_begin
            \(commands.map { $0.rawValue }.joined(separator: "\n"))
            command_list_end
            """
        case .albumart(let uri, let offset): return "albumart \"\(uri)\" \(offset)"
        case .next: return "next"
        case .pause: return "pause"
        case .repeat(let enabled): return "repeat \(enabled ? 1 : 0)"
        case .random(let enabled): return "random \(enabled ? 1 : 0)"
        case .play(let position):
            if let position = position {
                return "play \(position)"
            }
            return "play"
        case .playlistinfo: return "playlistinfo"
        case .previous: return "previous"
        case .status: return "status"
        case .search(let filter): return "search \"\(filter)\""
        case .setVolume(let volume): return "setvol \"\(volume)\""
        case .seekCurrent(let position): return "seekcur \"\(Int(position))\""
        case .addToQueue(let uri, let position):
            guard let pos = position else {
                return "add \"\(uri)\""
            }
            return "add \"\(uri)\" \(pos)"
        case .clear: return "clear"
        case .delete(let start, let end):
            guard let end = end else {
                return "delete \(start)"
            }
            return "delete \(start) \(end)"
        }
    }

    typealias RawValue = String

    case commandList(commands: [MPDCommand])
    case status
    case playlistinfo
    case play(position: Int?)
    case pause
    case next
    case previous
    case `repeat`(_: Bool)
    case random(_: Bool)
    case albumart(uri: String, offset: Int)
    case search(filter: String)
    case addToQueue(uri: String, position: Int?)
    case clear
    case delete(start: Int, end: Int?)
    case setVolume(volume: Int)
    case seekCurrent(position: TimeInterval)
}
