//
//  ExportFilenameTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Testing

@testable import StickiesDomain

struct ExportFilenameTests {
    @Test func keepsOrdinaryTitle() {
        #expect(ExportFilename.sanitized("Shopping List") == "Shopping List")
    }

    @Test func replacesIllegalPathCharacters() {
        #expect(ExportFilename.sanitized("a/b:c") == "a-b-c")
    }

    @Test func collapsesNewlinesIntoDashes() {
        #expect(ExportFilename.sanitized("first\nsecond") == "first-second")
    }

    @Test func emptyOrWhitespaceFallsBack() {
        #expect(ExportFilename.sanitized("") == ExportFilename.fallback)
        #expect(ExportFilename.sanitized("   ") == ExportFilename.fallback)
    }
}
