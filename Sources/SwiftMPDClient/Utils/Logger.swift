//
//  File.swift
//
//
//  Created by Dawid Dziurdzia on 04/03/2024.
//

import OSLog

@available(iOS 14.0, *)
@available(macOS 11.0, *)
extension Logger {
    init<T>(forType type: T.Type) {
        let subsystem = Bundle.main.bundleIdentifier!
        let category = String(describing: type)
        self.init(subsystem: subsystem, category: category)
    }
}
