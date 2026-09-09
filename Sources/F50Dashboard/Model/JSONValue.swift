import Foundation

/// goform 接口的返回值类型很随意：同一语义的字段可能是数字、字符串，
/// 甚至在无数据时退化成空字符串（例如 station_list 无终端时返回 ""）。
/// 用一个宽松的中间表示接住，再由调用方按需要的类型取值。
enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    /// 空字符串一律当作“无数据”，避免把 "" 当成合法值渲染到界面上。
    var stringValue: String? {
        switch self {
        case .string(let value): return value.isEmpty ? nil : value
        case .number(let value):
            return value == value.rounded() ? String(Int(value)) : String(value)
        case .bool(let value): return value ? "1" : "0"
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return value.isEmpty ? nil : Double(value)
        case .bool(let value): return value ? 1 : 0
        default: return nil
        }
    }

    var intValue: Int? {
        guard let value = doubleValue else { return nil }
        return Int(value)
    }

    var arrayValue: [JSONValue] {
        if case .array(let values) = self { return values }
        return []
    }

    subscript(key: String) -> JSONValue {
        if case .object(let dict) = self, let value = dict[key] { return value }
        return .null
    }
}
