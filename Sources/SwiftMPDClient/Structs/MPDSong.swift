//
//  MPDSong.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/01/2024.
//

import Foundation

public struct MPDSong: Identifiable, Equatable {
    init(artist: String, album: String, title: String, uri: String) {
        self._artist = artist
        self._album = album
        self._title = title
        self._uri = uri
    }

    public var id: String {
        return uri
    }

    let _artist: String
    let _album: String
    let _title: String
    let _uri: String

    public var artist: String { return _artist }
    public var album: String { return _album }
    public var title: String { return _title }
    public var uri: String { return _uri }
}
