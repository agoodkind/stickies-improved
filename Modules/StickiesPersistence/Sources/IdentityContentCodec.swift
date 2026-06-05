//
//  IdentityContentCodec.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

/// Passes note content through as UTF-8 with no transformation. This keeps the
/// `ContentCodec` seam wired while leaving real encryption for later.
public struct IdentityContentCodec: ContentCodec {
    public init() {
        // No state to configure.
    }

    public func encode(_ text: String) -> Data {
        Data(text.utf8)
    }

    public func decode(_ data: Data) -> String {
        String(bytes: data, encoding: .utf8) ?? ""
    }
}
