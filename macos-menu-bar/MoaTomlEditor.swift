import Foundation

enum MoaTomlEditor {
    struct Entry {
        let table: String
        let key: String
        let value: String
        let lineRange: Range<String.Index>

        var path: String {
            table.isEmpty ? key : "\(table).\(key)"
        }

        var lineText: String {
            "\(key) = \(value)"
        }
    }

    static func entries(in text: String) -> [Entry] {
        var entries: [Entry] = []
        var currentTable = ""
        var lineStart = text.startIndex

        while lineStart < text.endIndex {
            let nextLineStart = text[lineStart...].firstIndex(of: "\n").map { text.index(after: $0) } ?? text.endIndex
            let lineEnd = nextLineStart > lineStart && text[text.index(before: nextLineStart)] == "\n"
                ? text.index(before: nextLineStart)
                : nextLineStart
            let line = String(text[lineStart..<lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let tableName = tableName(from: trimmed) {
                currentTable = tableName
            } else if let keyValue = keyValue(from: line) {
                entries.append(Entry(table: currentTable, key: keyValue.key, value: keyValue.value, lineRange: lineStart..<lineEnd))
            }

            lineStart = nextLineStart
        }

        return entries
    }

    static func tableName(from line: String) -> String? {
        let trimmed = trimInlineComment(from: line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              trimmed.hasSuffix("]"),
              !trimmed.hasPrefix("[["),
              !trimmed.hasSuffix("]]")
        else {
            return nil
        }

        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        let name = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func keyValue(from line: String) -> (key: String, value: String)? {
        let scanner = Scanner(string: line)
        scanner.charactersToBeSkipped = nil

        _ = scanner.scanCharacters(from: .whitespacesAndNewlines)
        guard let rawKey = scanner.scanUpToString("=") else {
            return nil
        }

        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, scanner.scanString("=") != nil else {
            return nil
        }

        let remainder = String(line[scanner.currentIndex...])
        let value = trimInlineComment(from: remainder).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        return (key, value)
    }

    static func trimInlineComment(from value: String) -> String {
        var quote: Character?
        var previousWasEscape = false

        for index in value.indices {
            let character = value[index]

            if let currentQuote = quote {
                if currentQuote == "'" {
                    if character == "'" {
                        quote = nil
                    }
                    continue
                }

                if character == currentQuote && !previousWasEscape {
                    quote = nil
                    previousWasEscape = false
                    continue
                }
                if character == "\\" && !previousWasEscape {
                    previousWasEscape = true
                } else {
                    previousWasEscape = false
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                previousWasEscape = false
                continue
            }

            if character == "#" {
                return String(value[..<index])
            }
        }

        return value
    }

    static func collapseBlankLines(_ text: String) -> String {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while output.contains("\n\n\n") {
            output = output.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return output
    }

    static func collapseBlankLinesBeforeTables(_ text: String) -> String {
        var output = collapseBlankLines(text)

        var lines: [String] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if tableName(from: trimmed) != nil,
               let previousLine = lines.last,
               !previousLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("")
            }
            lines.append(line)
        }
        output = lines.joined(separator: "\n")
        while output.contains("\n\n\n") {
            output = output.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return output
    }

    static func quotedString(_ value: String) -> String {
        "\"\(escapedStringContent(value))\""
    }

    static func escapedStringContent(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    static func unquoteString(_ raw: String) -> String {
        var value = raw
        if value.count >= 2 {
            let quote = value.first
            value.removeFirst()
            value.removeLast()
            guard quote == "\"" else {
                return value
            }
        }

        var output = ""
        var isEscaped = false
        for character in value {
            if isEscaped {
                switch character {
                case "b":
                    output.append("\u{08}")
                case "t":
                    output.append("\t")
                case "n":
                    output.append("\n")
                case "f":
                    output.append("\u{0C}")
                case "r":
                    output.append("\r")
                case "\"":
                    output.append("\"")
                case "\\":
                    output.append("\\")
                default:
                    output.append("\\")
                    output.append(character)
                }
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                output.append(character)
            }
        }

        if isEscaped {
            output.append("\\")
        }
        return output
    }
}
