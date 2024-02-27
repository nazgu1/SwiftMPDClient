//
//  MPDState.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/01/2024.
//

import Foundation

public enum MPDState {
    case unknown
    case stop
    case play
    case pause

    init(string: String) {
        switch string {
        case "stop":
            self = .stop
        case "play":
            self = .play
        case "pause":
            self = .pause
        default:
            self = .unknown
        }
    }
}
