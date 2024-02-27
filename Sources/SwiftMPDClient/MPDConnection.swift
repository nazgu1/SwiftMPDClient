//
//  MPDConnection.swift
//  Orchestra
//
//  Created by Dawid Dziurdzia on 23/02/2024.
//

import Foundation
import Network

protocol MPDConnectable {
    func connect() async throws
    func disconnect() async
    
    func send(_ data: Data) async throws
    func receive() async throws -> Data
}

@available(macOS 10.15, *)
public final actor MPDConnection: MPDConnectable {
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private var connection: NWConnection?
    private let queue: DispatchQueue = .init(label: "pl.dziurdzia.orchestra.MPDConnectionQueue")
    private var semaphore = Semaphore(count: 1)
    
    public init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
    }
    
    func connect() async throws {
        let connection = NWConnection(host: host, port: port, using: .tcp)
        connection.start(queue: queue)
        
        try await withCheckedThrowingContinuation { cont in
            connection.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    print("Connected to MPD.")
                    cont.resume()
                case .failed(let error):
                    print("Failed to connect with error \(error)")
                    cont.resume(throwing: error)
                default:
                    break
                }
            }
        }

        self.connection = connection
        
        guard let data = try? await _receive(),
              let response = String(data: data, encoding: .utf8),
              response.contains("OK MPD")
        else {
            throw MPDError.notConnected
        }
    }
    
    func disconnect() async {
        connection?.cancel()
        connection = nil
    }
    
    func send(_ data: Data) async throws {
        guard let connection = connection else {
            throw MPDError.notConnected
        }
        await semaphore.wait()
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            })
        }
    }
    
    func receive() async throws -> Data {
        var response = Data()
        repeat {
            let data = try await _receive()
            response.append(data)
            
            if data.range(of: "OK\n".data(using: .utf8)!) != nil ||
                data.range(of: "\nACK [".data(using: .utf8)!) != nil
            {
                break
            }
            
        } while true
        
        await semaphore.release()
        return response
    }
    
    private func _receive() async throws -> Data {
        guard let connection = connection else {
            throw MPDError.notConnected
        }
        
        let received: Data? = try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: Int.max) { content, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: content)
            }
        }
        
        guard let receivedData = received else {
            throw MPDError.receiveFailed
        }
        
        return receivedData
    }
}
