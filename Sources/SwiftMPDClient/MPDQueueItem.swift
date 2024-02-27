//
//  MPDQueueItem.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/02/2024.
//

import Foundation

public struct MPDQueueItem: Identifiable, Equatable {
    public var id: Int
    var pos: Int
    public var song: MPDSong
}
