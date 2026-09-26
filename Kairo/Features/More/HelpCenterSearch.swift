import Foundation

enum HelpSearchResultKind: String, Equatable, Sendable {
    case guide = "Guide"
    case faq = "FAQ"
}

enum HelpSearchDestination: Equatable, Sendable {
    case guide(HelpGuide)
    case faq(HelpFAQ)
}

struct HelpSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let kind: HelpSearchResultKind
    let title: String
    let snippet: String
    let rank: Int
    let sourceOrder: Int
    let destination: HelpSearchDestination
}

nonisolated enum HelpCenterSearch {
    private enum MatchQuality: Int, Comparable {
        case exact = 0
        case prefix = 1
        case typo = 2

        static func < (lhs: MatchQuality, rhs: MatchQuality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    static func search(_ query: String) -> [HelpSearchResult] {
        let queryWords = words(query)

        if queryWords.isEmpty {
            return allResults()
        }

        let normalizedQuery = queryWords.joined(separator: " ")
        return allResults().compactMap { result in
            let titleWords = words(result.title)
            let bodyWords = words(searchableBody(for: result))
            guard let rank = rank(
                normalizedQuery: normalizedQuery,
                terms: queryWords,
                titleWords: titleWords,
                bodyWords: bodyWords
            ) else {
                return nil
            }

            return HelpSearchResult(
                id: result.id,
                kind: result.kind,
                title: result.title,
                snippet: result.snippet,
                rank: rank,
                sourceOrder: result.sourceOrder,
                destination: result.destination
            )
        }
        .sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            if $0.sourceOrder != $1.sourceOrder { return $0.sourceOrder < $1.sourceOrder }
            return $0.id < $1.id
        }
    }

    static func normalizedWords(_ value: String) -> [String] {
        words(value)
    }

    private static func allResults() -> [HelpSearchResult] {
        let guides = HelpCenterContent.guides.enumerated().map { index, guide in
            HelpSearchResult(
                id: "guide.\(guide.id)",
                kind: .guide,
                title: guide.title,
                snippet: guide.subtitle,
                rank: 0,
                sourceOrder: index,
                destination: .guide(guide)
            )
        }

        let offset = guides.count
        let faqs = HelpCenterContent.faqs.enumerated().map { index, faq in
            HelpSearchResult(
                id: "faq.\(faq.id)",
                kind: .faq,
                title: faq.question,
                snippet: faq.answer,
                rank: 0,
                sourceOrder: offset + index,
                destination: .faq(faq)
            )
        }

        return guides + faqs
    }

    private static func searchableBody(for result: HelpSearchResult) -> String {
        switch result.destination {
        case .guide(let guide):
            return ([guide.subtitle] + guide.sections.flatMap { [$0.title, $0.body] })
                .joined(separator: " ")
        case .faq(let faq):
            return faq.answer
        }
    }

    private static func rank(
        normalizedQuery: String,
        terms: [String],
        titleWords: [String],
        bodyWords: [String]
    ) -> Int? {
        let normalizedTitle = titleWords.joined(separator: " ")
        if normalizedTitle == normalizedQuery {
            return 0
        }

        if let quality = coverage(of: terms, in: titleWords), quality != .typo {
            return 1
        }

        if normalizedTitle.contains(normalizedQuery) {
            return 2
        }

        if let quality = coverage(of: terms, in: bodyWords), quality != .typo {
            return 3
        }

        if coverage(of: terms, in: titleWords) != nil || coverage(of: terms, in: bodyWords) != nil {
            return 4
        }

        return nil
    }

    private static func coverage(of terms: [String], in searchableWords: [String]) -> MatchQuality? {
        var overall = MatchQuality.exact

        for term in terms {
            guard let best = searchableWords.compactMap({ matchQuality(word: $0, term: term) }).min() else {
                return nil
            }
            overall = max(overall, best)
        }

        return overall
    }

    private static func matchQuality(word: String, term: String) -> MatchQuality? {
        if word == term { return .exact }
        if word.hasPrefix(term) { return .prefix }
        return isOneBoundedTypo(word: word, term: term) ? .typo : nil
    }

    private static func isOneBoundedTypo(word: String, term: String) -> Bool {
        guard term.count >= 5, abs(word.count - term.count) <= 1 else {
            return false
        }

        let wordCharacters = Array(word)
        let termCharacters = Array(term)

        if wordCharacters.count == termCharacters.count {
            let differences = zip(wordCharacters, termCharacters)
                .indicesWhereCharactersDiffer()
            if differences.count == 1 { return true }
            if differences.count == 2 {
                let first = differences[0]
                let second = differences[1]
                return second == first + 1
                    && wordCharacters[first] == termCharacters[second]
                    && wordCharacters[second] == termCharacters[first]
            }
            return false
        }

        let longer = wordCharacters.count > termCharacters.count ? wordCharacters : termCharacters
        let shorter = wordCharacters.count > termCharacters.count ? termCharacters : wordCharacters
        var longerIndex = 0
        var shorterIndex = 0
        var skipped = false

        while longerIndex < longer.count, shorterIndex < shorter.count {
            if longer[longerIndex] == shorter[shorterIndex] {
                longerIndex += 1
                shorterIndex += 1
            } else if skipped {
                return false
            } else {
                skipped = true
                longerIndex += 1
            }
        }

        return true
    }

    private static func words(_ value: String) -> [String] {
        value
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

private extension Zip2Sequence<Array<Character>, Array<Character>> {
    nonisolated func indicesWhereCharactersDiffer() -> [Int] {
        enumerated().compactMap { index, pair in
            pair.0 == pair.1 ? nil : index
        }
    }
}
