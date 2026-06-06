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
import os

/// A single note stored as an Automerge document so concurrent edits from different devices
/// merge character-by-character instead of one side overwriting the other. The body lives as
/// an Automerge `Text` object (the sequence CRDT) and the metadata fields live as scalar
/// registers in a nested map, each a last-writer-wins register so a color change on one
/// device and a font change on another both survive a merge.
///
/// Automerge's `Document` is a reference type and is not thread-safe, so a `NoteCRDT` is a
/// reference type too and is used from a single isolation domain (the main-actor workspace
/// model). Synchronization across devices moves serialized `Data`, never the live document,
/// so the persistence actor only ever handles bytes.
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

    private static let epoch = Date(timeIntervalSince1970: 0)

    private let document: Document
    private let logger = Logger(
        subsystem: "io.goodkind.stickies-improved", category: "NoteCRDT"
    )

    private init(document: Document) {
        self.document = document
    }

    /// Builds a fresh CRDT seeded with an existing note's body and metadata, for the first
    /// time a plain-text note is promoted into the merge-aware format.
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

    /// Merges another copy of the same note into this one. Automerge resolves concurrent body
    /// edits via the sequence CRDT and concurrent metadata edits per field, so the result is
    /// deterministic regardless of merge order. Merging a document with a copy of itself is a
    /// no-op, which is what makes the autosave reload loop harmless.
    public func merge(_ other: NoteCRDT) throws {
        try document.merge(other: other.document)
    }

    // MARK: - Body

    public var bodyText: String {
        guard let body = bodyObjectID() else {
            return ""
        }
        return perform("read body text", default: "") {
            try self.document.text(obj: body)
        }
    }

    /// Replaces the body with new text. `updateText` diffs against the current contents and
    /// applies only the minimal splices, so unchanged characters keep their CRDT identity and
    /// a remote cursor or concurrent edit is not disturbed by an unrelated keystroke.
    public func setBodyText(_ newText: String) {
        guard let body = bodyObjectID() else {
            return
        }
        perform("update body text") {
            try self.document.updateText(obj: body, value: newText)
        }
    }

    // MARK: - Metadata

    /// Writes every persisted metadata field into the CRDT's scalar registers. Title and
    /// excerpt are derived from the body, so they are recomputed on materialization rather
    /// than stored.
    public func apply(metadata: NoteMetadata) {
        guard let meta = metaObjectID() else {
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

    /// Updates a single metadata field rather than the whole record, so a concurrent edit to a
    /// different field on another device survives the merge. Each setter also stamps
    /// `updatedAt`, the one register where last-writer-wins is the intended behavior.

    public func setColor(_ color: NoteColor, updatedAt: Date) {
        guard let meta = metaObjectID() else {
            return
        }
        putString(color.rawValue, key: Key.colorName, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setFont(name: String?, size: Double, updatedAt: Date) {
        guard let meta = metaObjectID() else {
            return
        }
        putOptionalString(name, key: Key.fontName, in: meta)
        putDouble(size, key: Key.fontSize, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setFontColor(hex: String?, updatedAt: Date) {
        guard let meta = metaObjectID() else {
            return
        }
        putOptionalString(hex, key: Key.fontColorHex, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setFrame(_ frame: NoteFrame?) {
        guard let meta = metaObjectID() else {
            return
        }
        applyFrame(frame, in: meta)
    }

    public func setCollapsed(_ collapsed: Bool, expandedHeight: Double?) {
        guard let meta = metaObjectID() else {
            return
        }
        putBool(collapsed, key: Key.collapsed, in: meta)
        putOptionalDouble(expandedHeight, key: Key.expandedHeight, in: meta)
    }

    public func setTrashed(_ isTrashed: Bool, updatedAt: Date) {
        guard let meta = metaObjectID() else {
            return
        }
        putBool(isTrashed, key: Key.isTrashed, in: meta)
        putDate(updatedAt, key: Key.updatedAt, in: meta)
    }

    public func setUpdatedAt(_ date: Date) {
        guard let meta = metaObjectID() else {
            return
        }
        putDate(date, key: Key.updatedAt, in: meta)
    }

    /// Reconstructs the full `NoteDocument` from the CRDT. The id falls back to the passed
    /// value only when the document predates id storage, so a note round-trips to itself.
    public func materialized(fallbackID: NoteID) -> NoteDocument {
        guard let meta = metaObjectID() else {
            let metadata = NoteMetadata(id: fallbackID, mode: .plainText)
            return NoteDocument(metadata: metadata, plainText: bodyText)
        }
        let id = (readString(Key.id, in: meta).flatMap(NoteID.init)) ?? fallbackID
        let mode = (readString(Key.mode, in: meta).flatMap(NoteMode.init(rawValue:))) ?? .plainText
        let color =
            (readString(Key.colorName, in: meta).flatMap(NoteColor.init(rawValue:))) ?? .default
        let metadata = NoteMetadata(
            id: id,
            mode: mode,
            createdAt: readDate(Key.createdAt, in: meta) ?? Self.epoch,
            updatedAt: readDate(Key.updatedAt, in: meta) ?? Self.epoch,
            colorName: color,
            fontName: readString(Key.fontName, in: meta),
            fontSize: readDouble(Key.fontSize, in: meta) ?? NoteMetadata.Default.fontSize,
            fontColorHex: readString(Key.fontColorHex, in: meta),
            frame: readFrame(in: meta),
            collapsed: readBool(Key.collapsed, in: meta, default: NoteMetadata.Default.collapsed),
            expandedHeight: readDouble(Key.expandedHeight, in: meta),
            isTrashed: readBool(Key.isTrashed, in: meta, default: NoteMetadata.Default.isTrashed)
        )
        return NoteDocument(metadata: metadata, plainText: bodyText)
    }

    // MARK: - Object resolution

    /// Returns the body `Text` object, creating it on first use. Tolerates a fresh document
    /// where the key does not exist yet.
    private func bodyObjectID() -> ObjId? {
        if case let .Object(id, .Text)? = currentValue(Key.body, in: ObjId.ROOT) {
            return id
        }
        return perform("create body object", default: nil) {
            try self.document.putObject(obj: ObjId.ROOT, key: Key.body, ty: .Text)
        }
    }

    private func metaObjectID() -> ObjId? {
        if case let .Object(id, .Map)? = currentValue(Key.meta, in: ObjId.ROOT) {
            return id
        }
        return perform("create meta object", default: nil) {
            try self.document.putObject(obj: ObjId.ROOT, key: Key.meta, ty: .Map)
        }
    }

    private func currentValue(_ key: String, in obj: ObjId) -> Value? {
        perform("read \(key)", default: nil) {
            try self.document.get(obj: obj, key: key)
        }
    }

    // MARK: - Frame

    private func applyFrame(_ frame: NoteFrame?, in meta: ObjId) {
        guard let frame else {
            putValue(.Null, key: Key.frame, in: meta)
            return
        }
        guard let frameObject = frameObjectID(in: meta) else {
            return
        }
        putDouble(frame.x, key: Key.frameX, in: frameObject)
        putDouble(frame.y, key: Key.frameY, in: frameObject)
        putDouble(frame.width, key: Key.frameWidth, in: frameObject)
        putDouble(frame.height, key: Key.frameHeight, in: frameObject)
    }

    private func frameObjectID(in meta: ObjId) -> ObjId? {
        if case let .Object(id, .Map)? = currentValue(Key.frame, in: meta) {
            return id
        }
        return perform("create frame object", default: nil) {
            try self.document.putObject(obj: meta, key: Key.frame, ty: .Map)
        }
    }

    private func readFrame(in meta: ObjId) -> NoteFrame? {
        guard case let .Object(frameObject, .Map)? = currentValue(Key.frame, in: meta) else {
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
        putValue(.String(value), key: key, in: obj)
    }

    private func putOptionalString(_ value: String?, key: String, in obj: ObjId) {
        if let value {
            putValue(.String(value), key: key, in: obj)
        } else {
            putValue(.Null, key: key, in: obj)
        }
    }

    private func putDouble(_ value: Double, key: String, in obj: ObjId) {
        putValue(.F64(value), key: key, in: obj)
    }

    private func putOptionalDouble(_ value: Double?, key: String, in obj: ObjId) {
        if let value {
            putValue(.F64(value), key: key, in: obj)
        } else {
            putValue(.Null, key: key, in: obj)
        }
    }

    private func putBool(_ value: Bool, key: String, in obj: ObjId) {
        putValue(.Boolean(value), key: key, in: obj)
    }

    private func putDate(_ value: Date, key: String, in obj: ObjId) {
        putValue(.Timestamp(value), key: key, in: obj)
    }

    private func putValue(_ value: ScalarValue, key: String, in obj: ObjId) {
        perform("put \(key)") {
            try self.document.put(obj: obj, key: key, value: value)
        }
    }

    // MARK: - Scalar readers

    private func readString(_ key: String, in obj: ObjId) -> String? {
        if case let .Scalar(.String(value))? = currentValue(key, in: obj) {
            return value
        }
        return nil
    }

    private func readDouble(_ key: String, in obj: ObjId) -> Double? {
        if case let .Scalar(.F64(value))? = currentValue(key, in: obj) {
            return value
        }
        return nil
    }

    private func readBool(_ key: String, in obj: ObjId, default defaultValue: Bool) -> Bool {
        if case let .Scalar(.Boolean(value))? = currentValue(key, in: obj) {
            return value
        }
        return defaultValue
    }

    private func readDate(_ key: String, in obj: ObjId) -> Date? {
        if case let .Scalar(.Timestamp(value))? = currentValue(key, in: obj) {
            return value
        }
        return nil
    }

    // MARK: - Error handling

    /// Runs an Automerge call that returns a value, logging and falling back on failure. The
    /// project bans `try?`, so this is the single explicit handler the readers and writers
    /// funnel through. Automerge throws only on type or index misuse, which would be a bug, so
    /// logging plus a safe default keeps the note usable rather than crashing the editor.
    private func perform<T>(
        _ label: String,
        default defaultValue: T,
        _ body: () throws -> T
    ) -> T {
        do {
            return try body()
        } catch {
            logger.error("\(label) failed: \(error.localizedDescription, privacy: .public)")
            return defaultValue
        }
    }

    private func perform(_ label: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            logger.error("\(label) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
