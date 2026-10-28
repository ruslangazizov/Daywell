import Foundation

nonisolated func validatedName(_ value: String) throws -> String {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { throw ModelValidationError.emptyName }
    return value
}

nonisolated func validateTimestamp(_ value: Date) throws {
    guard value.timeIntervalSinceReferenceDate.isFinite else {
        throw ModelValidationError.invalidTimestamp
    }
}
