import Foundation

enum APIJSONCoder {
    nonisolated static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { nestedDecoder in
            let container = try nestedDecoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let timestamp = iso8601Date(from: value) {
                return timestamp
            }

            if let calendarDate = yyyyMMddDate(from: value) {
                return calendarDate
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        return decoder
    }

    private nonisolated static func iso8601Date(from value: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = [
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private nonisolated static func yyyyMMddDate(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
