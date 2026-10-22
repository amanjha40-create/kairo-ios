import Foundation

/// PATCH is three-state. Never use an absent optional to mean both retain and clear.
nonisolated enum OptionalFieldChange<Value: Encodable & Equatable & Sendable>: Equatable, Sendable {
    case unchanged
    case set(Value)
    case clear

    static func between(_ original: Value?, _ current: Value?) -> Self {
        guard original != current else { return .unchanged }
        return current.map(Self.set) ?? .clear
    }
    static func supplied(_ value: Value?) -> Self { value.map(Self.set) ?? .unchanged }
}

extension OptionalFieldChange where Value == String {
    nonisolated static func edited(original: String?, current: String, encoded: String?) -> Self {
        guard (original ?? "") != current else { return .unchanged }
        return encoded.map(Self.set) ?? .clear
    }
}

extension KeyedEncodingContainer {
    nonisolated mutating func encodeChange<Value>(_ change: OptionalFieldChange<Value>, forKey key: Key) throws {
        switch change {
        case .unchanged: break
        case .set(let value): try encode(value, forKey: key)
        case .clear: try encodeNil(forKey: key)
        }
    }
}

nonisolated struct PatchFieldKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

/// Opt-in encoder for PATCH DTOs only. Create/replacement/auth payloads do not use it.
nonisolated func encodeOptionalStringChanges(
    to encoder: Encoder, values: [String: String?],
    changes: [String: OptionalFieldChange<String>]
) throws {
    var container = encoder.container(keyedBy: PatchFieldKey.self)
    for (key, value) in values {
        try container.encodeChange(changes[key] ?? .supplied(value), forKey: PatchFieldKey(key))
    }
}
