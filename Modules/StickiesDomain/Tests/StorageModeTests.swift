//
//  StorageModeTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Testing

@testable import StickiesDomain

struct StorageModeTests {
    @Test func rawValueRoundTrip() {
        for mode in StorageMode.allCases {
            #expect(StorageMode(rawValue: mode.rawValue) == mode)
        }
    }

    @Test func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in StorageMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(StorageMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test func defaultIsiCloud() {
        #expect(StorageMode.default == .iCloud)
    }
}
