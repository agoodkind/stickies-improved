//
//  NoteCRDT.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 06/06/2026.
//  Copyright © 2026, all rights reserved.
//

import Automerge
import Foundation
import StickiesDomain

/// A single note stored as an Automerge document so concurrent edits from different
/// devices merge character-by-character instead of one side overwriting the other.
/// The body lives as an Automerge `Text` object (the sequence CRDT) and the metadata
/// fields live as scalar registers in a nested map, each a last-writer-wins register so
/// a color change on one device and a font change on another both survive a merge.
///
/// Automerge's `Document` is a reference type and is not thread-safe, so a `NoteCRDT` is
/// a reference type too and is expected to be used from a single isolation domain (the
/// main-actor workspace model). Synchronization across devices moves serialized `Data`,
/// never the live document, so the persistence actor only ever handles bytes.
public final class NoteCRDT {
    private enum Key {
        static let body = "body"
        static let meta = "meta"
        static let id = "id"
        static let mode = "mode"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let colorName = "colorName"
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let fontColorHex = "fontColorHex"
        static let frame = "frame"
        static let frameX = "x"
        static let frameY = "y"
        static let frameWidth = "width"
        static let frameHeight = "height"
        static let collapsed = "collapsed"
        static let expandedHeight = "expandedHeight"
        static let isTrashed = "isTrashed"
    }

    private let document: Document

    private init(document: Document) {
        self.document = document
    }

    /// Builds a fresh CRDT seeded with an existing note's body and metadata, for the
    /// first time a plain-text note is promoted into the merge-aware format.
    public static func seeded(from note: NoteDocument) -> NoteCRDT {
        let crdt = NoteCRDT(document: Document())
        crdt.setBodyText(note.plainText)
        crdt.apply(metadata: note.metadata)
        return crdt
    }

    /// Reconstructs a CRDT from its serialized bytes (the `note.automerge` package file).
    public static func load(from data: Data) throws -> NoteCRDT {
        NoteCRDT(document: try Document(data))
    }

    /// The compressed Automerge document, including full edit history, for writing to disk.
    public func serialized() -> Data {
        document.save()
    }

    /// Merges another copy of the same note into this one. Automerge resolves concurrent
    /// body edits via the sequence CRDT and concurrent metadata edits per field, so the
    /// result is deterministic regardless of merge order. Merging a document with a copy
    /// of itself is a no-op, which is what makes the autosave reload loop harmless.
    public func merge(_ other: NoteCRDT) throws {
        try document.merge(other: other.document)
    }

    // MARK: - Body

    public var bodyText: String {
        guard let body = try? bodyObjectID() else {
            return ""
        }
        return (try? document.text(obj: body)) ?? ""
    }

    /// Replaces the body with new text. `updateText` diffs against the current contents and
    /// applies only the minimal splices, so unchanged characters keep their CRDT identity
    /// and a remote cursor or concurrent edit is not disturbed by an unrelated keystroke.
    public func setBodyText(_ newText: String) {
        guard let body = try? bodyObjectID() else {
            return
        }
        try? document.updateText(obj: body, value: newText)
    }

    // MARK: - Metadata

    /// Writes every persisted metadata field into the CRDT's scalar registers. Title and
    /// excerpt are derived from the body, so they are recomputed on materialization rather
    /// than stored.
    public func apply(metadata: NoteMetadata) {
        guard let meta = try? metaObjectID() else {
            return
        }
        putString(metadata.id.description, key: Key.id, in: meta)
        putString(metadata.mode.rawValue, key: Key.mode, in: meta)
        putDate(metadata.createdAt, key: Key.createdAt, in: meta)
        putDate(metadata.updatedAt, key: Key.updatedAt, in: meta)
        putString(metadata.colorName.rawValue, key: Key.colorName, in: meta)
        putOptionalString(metadata.fontName, key: Key.fontName, in: meta)
        putDouble(metadata.fontSize, key: Key.fontSize, in: meta)
        putOptionalString(metadata.fontColorHex, key: Key.fontColorHex, in: meta)
        putBool(metadata.collapsed, key: Key.collapsed, in: meta)
        putOptionalDouble(metadata.expandedHeight, key: Key.expandedHeight, in: meta)
        putBool(metadata.isTrashed, key: Key.isTrashed, in: meta)
        applyFrame(metadata.frame, in: meta)
    }

    /// Updates a single metadata field rather than the whole record, so a concurrent edit
    /// to a different field on another device survives the merge. Each setter also stamps
    /// `updatedAt`, the one register where last-writer-wins is the intended behavior.

    public func setColor(_ color: NoteColor, updatedAt: Date) {
        guard let meta = try? metaObjectID() else { return }
        putString(color.rawValue, key: Key.colorName, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setFont(name: String?, size: Double, updatedAt: Date) {
        guard let meta = try? metaObjectID() else { return }
        putOptionalString(name, key: Key.fontName, in: meta)
        putDouble(size, key: Key.fontSize, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setFontColor(hex: String?, updatedAt: Date) {
        guard let meta = try? metaObjectID() else { return }
        putOptionalString(hex, key: Key.fontColorHex, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setFrame(_ frame: NoteFrame?) {
        guard let meta = try? metaObjectID() else { return }
        applyFrame(frame, in: meta)
    }

    public func setCollapsed(_ collapsed: Bool, expandedHeight: Double?) {
        guard let meta = try? metaObjectID() else { return }
        putBool(collapsed, key: Key.collapsed, in: meta)
        putOptionalDouble(expandedHeight, key: Key.expandedHeight, in: meta)
    }

    public func setTrashed(_ isTrashed: Bool, updatedAt: Date) {
        guard let meta = try? metaObjectID() else { return }
        putBool(isTrashed, key: Key.isTrashed, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setUpdatedAt(_ date: Date) {
        guard let meta = try? metaObjectID() else { return }
        putDate(date, key: Key.updatedAt, in: meta)
    }

    /// Reconstructs the full `NoteDocument` from the CRDT. The id falls back to the passed
    /// value only when the document predates id storage, so a note round-trips to itself.
    public func materialized(fallbackID: NoteID) -> NoteDocument {
        let meta = try? metaObjectID()
        let id = meta.flatMap { readString(Key.id, in: $0) }.flatMap(NoteID.init) ?? fallbackID
        let mode =
            meta.flatMap { readString(Key.mode, in: $0) }
            .flatMap(NoteMode.init(rawValue:)) ?? .plainText
        let metadata = NoteMetadata(
            id: id,
            mode: mode,
            createdAt: meta.flatMap { readDate(Key.createdAt, in: $0) } ?? Date(timeIntervalSince1970: 0),
            updatedAt: meta.flatMap { readDate(Key.updatedAt, in: $0) } ?? Date(timeIntervalSince1970: 0),
            colorName: meta.flatMap { readString(Key.colorName, in: $0) }
                .flatMap(NoteColor.init(rawValue:)) ?? .default,
            fontName: meta.flatMap { readString(Key.fontName, in: $0) },
            fontSize: meta.flatMap { readDouble(Key.fontSize, in: $0) } ?? NoteMetadata.Default.fontSize,
            fontColorHex: meta.flatMap { readString(Key.fontColorHex, in: $0) },
            frame: meta.flatMap { readFrame(in: $0) },
            collapsed: meta.flatMap { readBool(Key.collapsed, in: $0) } ?? NoteMetadata.Default.collapsed,
            expandedHeight: meta.flatMap { readDouble(Key.expandedHeight, in: $0) },
            isTrashed: meta.flatMap { readBool(Key.isTrashed, in: $0) } ?? NoteMetadata.Default.isTrashed
        )
        return NoteDocument(metadata: metadata, plainText: bodyText)
    }

    // MARK: - Object resolution

    /// Returns the body `Text` object, creating it on first use. The lookup tolerates a
    /// fresh document where the key does not exist yet.
    private func bodyObjectID() throws -> ObjId {
        if case let .Object(id, .Text)? = try document.get(obj: ObjId.ROOT, key: Key.body) {
            return id
        }
        return try document.putObject(obj: ObjId.ROOT, key: Key.body, ty: .Text)
    }

    private func metaObjectID() throws -> ObjId {
        if case let .Object(id, .Map)? = try document.get(obj: ObjId.ROOT, key: Key.meta) {
            return id
        }
        return try document.putObject(obj: ObjId.ROOT, key: Key.meta, ty: .Map)
    }

    // MARK: - Frame

    private func applyFrame(_ frame: NoteFrame?, in meta: ObjId) {
        guard let frame else {
            try? document.put(obj: meta, key: Key.frame, value: .Null)
            return
        }
        let frameObject: ObjId
        if case let .Object(id, .Map)? = try? document.get(obj: meta, key: Key.frame) {
            frameObject = id
        } else if let created = try? document.putObject(obj: meta, key: Key.frame, ty: .Map) {
            frameObject = created
        } else {
            return
        }
        putDouble(frame.x, key: Key.frameX, in: frameObject)
        putDouble(frame.y, key: Key.frameY, in: frameObject)
        putDouble(frame.width, key: Key.frameWidth, in: frameObject)
        putDouble(frame.height, key: Key.frameHeight, in: frameObject)
    }

    private func readFrame(in meta: ObjId) -> NoteFrame? {
        guard case let .Object(frameObject, .Map)? = try? document.get(obj: meta, key: Key.frame)
        else {
            return nil
        }
        guard let x = readDouble(Key.frameX, in: frameObject),
            let y = readDouble(Key.frameY, in: frameObject),
            let width = readDouble(Key.frameWidth, in: frameObject),
            let height = readDouble(Key.frameHeight, in: frameObject)
        else {
            return nil
        }
        return NoteFrame(x: x, y: y, width: width, height: height)
    }

    // MARK: - Scalar writers

    private func putString(_ value: String, key: String, in obj: ObjId) {
        try? document.put(obj: obj, key: key, value: .String(value))
    }

    private func putOptionalString(_ value: String?, key: String, in obj: ObjId) {
        if let value {
            try? document.put(obj: obj, key: key, value: .String(value))
        } else {
            try? document.put(obj: obj, key: key, value: .Null)
        }
    }

    private func putDouble(_ value: Double, key: String, in obj: ObjId) {
        try? document.put(obj: obj, key: key, value: .F64(value))
    }

    private func putOptionalDouble(_ value: Double?, key: String, in obj: ObjId) {
        if let value {
            try? document.put(obj: obj, key: key, value: .F64(value))
        } else {
            try? document.put(obj: obj, key: key, value: .Null)
        }
    }

    private func putBool(_ value: Bool, key: String, in obj: ObjId) {
        try? document.put(obj: obj, key: key, value: .Boolean(value))
    }

    private func putDate(_ value: Date, key: String, in obj: ObjId) {
        try? document.put(obj: obj, key: key, value: .Timestamp(value))
    }

    // MARK: - Scalar readers

    private func readString(_ key: String, in obj: ObjId) -> String? {
        guard case let .Scalar(.String(value))? = try? document.get(obj: obj, key: key) else {
            return nil
        }
        return value
    }

    private func readDouble(_ key: String, in obj: ObjId) -> Double? {
        guard case let .Scalar(.F64(value))? = try? document.get(obj: obj, key: key) else {
            return nil
        }
        return value
    }

    private func readBool(_ key: String, in obj: ObjId) -> Bool? {
        guard case let .Scalar(.Boolean(value))? = try? document.get(obj: obj, key: key) else {
            return nil
        }
        return value
    }

    private func readDate(_ key: String, in obj: ObjId) -> Date? {
        guard case let .Scalar(.Timestamp(value))? = try? document.get(obj: obj, key: key) else {
            return nil
        }
        return value
    }
}
