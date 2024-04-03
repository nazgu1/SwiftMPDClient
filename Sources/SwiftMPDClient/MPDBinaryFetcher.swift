//
//  MPDBinaryFetcher.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/02/2024.
//

import Foundation

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public final actor MPDBinaryFetcher {
    private let connection: MPDConnection
    
    public init(connection: MPDConnection) {
        self.connection = connection
    }
    
    public func fetchAlbumArt(path: String) async throws -> Data {
        var size = 0
        var offset = 0
        var imageBinaryData = Data()
        
        try await connection.connect()
        
        repeat {
            let cmd = "albumart \"\(path)\" \(offset)\n"
            try await connection.send(cmd.data(using: .utf8)!)
            let data = try await connection.receive()
            
            let separator = "\n".data(using: .utf8)!
            let range = data.range(of: separator)
            let firstLine = Data(data[0 ..< range!.lowerBound])
            let firstLineString = String(data: firstLine, encoding: .utf8)!
            
            let range2 = data.range(of: separator, in: range!.upperBound ..< data.count)!
            let secondLine = Data(data[range!.upperBound ..< range2.lowerBound])
            let secondLineString = String(data: secondLine, encoding: .utf8)!
            
            let range3 = data.range(of: "\nOK".data(using: .utf8)!)!
            
            if firstLineString.starts(with: "size:") {
                if let sizeLine = firstLineString.split(separator: " ").last, let dataSize = Int(sizeLine) {
                    size = dataSize
                }
            }
            
            if secondLineString.starts(with: "binary:") {
                if let binaryLine = secondLineString.split(separator: " ").last, let dataSize = Int(binaryLine) {
                    offset += dataSize
                    let binaryData = data.subdata(in: range2.upperBound ..< range3.lowerBound)
                    imageBinaryData.append(binaryData)
                }
            }
        } while size > offset
        await connection.disconnect()
        return imageBinaryData
    }
}
