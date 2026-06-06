//
//  NoteCRDTTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 06/06/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import Testing

@testable import StickiesCRDT

struct NoteCRDTTests {
    private func sampleNote() -> NoteDocument {
        let metadata = NoteMetadata(
            id: NoteID(),
            mode: .plainText,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            colorName: .blue,
            fontName: "Menlo-Regular",
            fontSize: 18,
            fontColorHex: "#112233",
            frame: NoteFrame(x: 12, y: 34, width: 300, height: 400),
            collapsed: true,
            expandedHeight: 420,
            isTrashed: false
        )
        return NoteDocument(metadata: metadata, plainText: "Hello world")
    }

    @Test func seedAndSerializeRoundTripsEveryField() throws {
        let original = sampleNote()

        let crdt = NoteCRDT.seeded(from: original)
        let reloaded = try NoteCRDT.load(from: crdt.serialized())
        let result = reloaded.materialized(fallbackID: original.id)

        #expect(result.plainText == original.plainText)
        #expect(result.id == original.id)
        #expect(result.metadata.mode == original.metadata.mode)
        #expect(result.metadata.createdAt == original.metadata.createdAt)
        #expect(result.metadata.updatedAt == original.metadata.updatedAt)
        #expect(result.metadata.colorName == original.metadata.colorName)
        #expect(result.metadata.fontName == original.metadata.fontName)
        #expect(result.metadata.fontSize == original.metadata.fontSize)
        #expect(result.metadata.fontColorHex == original.metadata.fontColorHex)
        #expect(result.metadata.frame == original.metadata.frame)
        #expect(result.metadata.collapsed == original.metadata.collapsed)
        #expect(result.metadata.expandedHeight == original.metadata.expandedHeight)
        #expect(result.metadata.isTrashed == original.metadata.isTrashed)
    }

    @Test func nilOptionalMetadataRoundTripsAsNil() throws {
        var note = sampleNote()
        note.metadata.fontName = nil
        note.metadata.fontColorHex = nil
        note.metadata.frame = nil
        note.metadata.expandedHeight = nil

        let crdt = NoteCRDT.seeded(from: note)
        let result = try NoteCRDT.load(from: crdt.serialized()).materialized(fallbackID: note.id)

        #expect(result.metadata.fontName == nil)
        #expect(result.metadata.fontColorHex == nil)
        #expect(result.metadata.frame == nil)
        #expect(result.metadata.expandedHeight == nil)
    }

    @Test func concurrentBodyEditsBothSurviveMerge() throws {
        let base = NoteCRDT.seeded(from: NoteDocument(plainText: "Hello"))
        let data = base.serialized()

        let deviceA = try NoteCRDT.load(from: data)
        let deviceB = try NoteCRDT.load(from: data)
        deviceA.setBodyText("Hello A")
        deviceB.setBodyText("B Hello")

        try deviceA.merge(deviceB)

        let merged = deviceA.bodyText
        #expect(merged.contains("A"))
        #expect(merged.contains("B"))
        #expect(merged.contains("Hello"))
    }

    @Test func bodyMergeConvergesRegardlessOfOrder() throws {
        let data = NoteCRDT.seeded(from: NoteDocument(plainText: "Hello")).serialized()

        let a1 = try NoteCRDT.load(from: data)
        let b1 = try NoteCRDT.load(from: data)
        a1.setBodyText("Hello A")
        b1.setBodyText("B Hello")
        try a1.merge(b1)

        let a2 = try NoteCRDT.load(from: data)
        let b2 = try NoteCRDT.load(from: data)
        a2.setBodyText("Hello A")
        b2.setBodyText("B Hello")
        try b2.merge(a2)

        #expect(a1.bodyText == b2.bodyText)
    }

    @Test func concurrentMetadataEditsToDifferentFieldsBothSurvive() throws {
        let data = NoteCRDT.seeded(from: sampleNote()).serialized()
        let editTime = Date(timeIntervalSince1970: 5_000)

        let deviceA = try NoteCRDT.load(from: data)
        let deviceB = try NoteCRDT.load(from: data)
        deviceA.setColor(.red, updatedAt: editTime)
        deviceB.setFont(name: "Courier", size: 24, updatedAt: editTime)

        try deviceA.merge(deviceB)
        let result = deviceA.materialized(fallbackID: sampleNote().id)

        #expect(result.metadata.colorName == .red)
        #expect(result.metadata.fontName == "Courier")
        #expect(result.metadata.fontSize == 24)
    }

    @Test func mergingACopyOfItselfLeavesBodyUnchanged() throws {
        let crdt = NoteCRDT.seeded(from: NoteDocument(plainText: "stable text"))
        let copy = try NoteCRDT.load(from: crdt.serialized())

        try crdt.merge(copy)

        #expect(crdt.bodyText == "stable text")
    }
}
