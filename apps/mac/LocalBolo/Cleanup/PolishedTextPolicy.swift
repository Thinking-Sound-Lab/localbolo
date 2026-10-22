import Foundation
import NaturalLanguage

/// Checks for obvious factual changes and unrelated output. These checks do not
/// prove semantic equivalence; the original passage remains the fallback.
nonisolated enum PolishedTextPolicy {
    static func accepts(_ edited: String, original: String, language: String?) -> Bool {
        let edited = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !edited.isEmpty, !hasWrapper(edited), edited.count <= original.count * 2 + 80 else { return false }

        let faithfulCorrection = language == "en" && TranscriptEditPolicy.isFaithful(edited, to: original)
        let originalCurrencies = currencies(in: original)
        let editedCurrencies = currencies(in: edited)
        guard originalCurrencies == editedCurrencies
            || (faithfulCorrection && !editedCurrencies.isEmpty
                && originalCurrencies.suffix(editedCurrencies.count).elementsEqual(editedCurrencies)) else { return false }

        // Retain the established, stricter policy for explicit English corrections.
        if faithfulCorrection { return true }

        guard numbers(in: edited) == numbers(in: original),
              wordFacts(in: edited) == wordFacts(in: original),
              negations(in: edited) == negations(in: original),
              protectedText(in: original).allSatisfy({ edited.localizedCaseInsensitiveContains($0) }),
              protectedText(in: edited).allSatisfy({ original.localizedCaseInsensitiveContains($0) }),
              scripts(in: edited).isSubset(of: scripts(in: original)) else { return false }

        let listCues: Set<String> = ["first", "second", "third", "fourth", "fifth", "firstly", "secondly", "thirdly"]
        let hasList = edited.contains(/\n\s*[-•]\s/)
        let comparisonOriginal = edited.contains("\n") ? removingParagraphCues(original) : original
        if language == "en" {
            // Grammar changes verb forms, not the underlying action. Comparing
            // lemmas permits go -> went but rejects approve -> reject.
            let beforeContent = contentWords(in: comparisonOriginal, ignoringListCues: hasList)
            let afterContent = contentWords(in: edited, ignoringListCues: hasList)
            guard beforeContent == afterContent else { return false }
        }
        let before = comparisonUnits(comparisonOriginal).filter { !hasList || !listCues.contains($0) }
        let after = comparisonUnits(edited)
        guard !before.isEmpty, !after.isEmpty else { return false }
        let shared = sharedCount(before, after)
        let minimum = before.count >= 8 ? 0.7 : 0.5
        return Double(shared) / Double(before.count) >= minimum && Double(shared) / Double(after.count) >= 0.5
    }

    private static func removingParagraphCues(_ text: String) -> String {
        // Only standalone commands, not quoted phrases or requests about writing
        // a paragraph. Literal quotes are separately protected above.
        text.replacingOccurrences(
            of: #"(?i)(?:^|(?<=[.!?。！？।])\s*)(?:new paragraph|नया पैराग्राफ|नई पंक्ति|另起一段|换行|改行|新しい段落)(?:[.!?。！？।]|$)"#,
            with: " ", options: .regularExpression
        )
    }

    private static func hasWrapper(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["<dictation", "</dictation", "<think", "```", "<|"].contains { lower.contains($0) }
            || ["here is the", "here's the", "corrected text:", "edited text:", "translation:"].contains { lower.hasPrefix($0) }
    }

    private static func numbers(in text: String) -> [String] {
        // List numbering is formatting, not a new dictated amount or date.
        let text = text.replacingOccurrences(of: #"(?m)^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
        return text.matches(of: #/\p{N}+(?:[.,:/-]\p{N}+)*/#).map {
            String($0.output).folding(options: .widthInsensitive, locale: nil)
        }
    }

    private static func negations(in text: String) -> Int {
        let normalized = text.lowercased().replacing("’", with: "'").replacing("n't", with: " not")
        let pattern = #"\b(?:not|no|never|cannot|without)\b|不|没|無|ない|ません|ぬ|नहीं|(?<![\p{L}\p{M}])(?:मत|ना|न)(?![\p{L}\p{M}])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.numberOfMatches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
    }

    private static func wordFacts(in text: String) -> [String] {
        let pattern = #"\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|thirty|forty|fifty|hundred|thousand|million|billion|monday|tuesday|wednesday|thursday|friday|saturday|sunday|january|february|march|april|may|june|july|august|september|october|november|december|today|tomorrow|yesterday)\b|[一二三四五六七八九十百千万亿]+|सोमवार|मंगलवार|बुधवार|गुरुवार|शुक्रवार|शनिवार|रविवार|今天|明天|昨天|后天|今日|明日|昨日|明後日"#
        let lower = text.lowercased()
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: lower, range: NSRange(lower.startIndex..., in: lower)).compactMap {
            Range($0.range, in: lower).map { String(lower[$0]) }
        }.sorted()
    }

    private static func contentWords(in text: String, ignoringListCues: Bool) -> Set<String> {
        // Preserve the unit when a model formats "250 dollars" as "$250".
        let text = text
            .replacingOccurrences(of: #"\$\s*(\p{N}+(?:[.,]\p{N}+)*)"#, with: "$1 dollars", options: .regularExpression)
            .replacingOccurrences(of: #"€\s*(\p{N}+(?:[.,]\p{N}+)*)"#, with: "$1 euros", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\byou know\b"#, with: "", options: .regularExpression)
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        tagger.setLanguage(.english, range: range)
        let auxiliaries: Set<String> = ["be", "have", "do", "can", "could", "may", "might", "must", "will", "would", "shall", "should"]
        let listCues: Set<String> = ["first", "second", "third", "fourth", "fifth", "firstly", "secondly", "thirdly"]
        var result: Set<String> = []
        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: [.omitWhitespace, .omitPunctuation]) { lemma, tokenRange in
            let kind = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass).0
            if kind == .noun || kind == .verb || kind == .adjective || kind == .adverb {
                let word = (lemma?.rawValue ?? String(text[tokenRange])).lowercased()
                if !auxiliaries.contains(word), !ignoringListCues || !listCues.contains(word) {
                    result.insert(word)
                }
            }
            return true
        }
        return result
    }

    private static func currencies(in text: String) -> [String] {
        let patterns: [(String, String)] = [
            ("dollar", #"\$\s*(\p{N}+(?:[.,]\p{N}+)*)|(\p{N}+(?:[.,]\p{N}+)*)\s*(?:dollars?\b|डॉलर|美元|ドル)"#),
            ("euro", #"€\s*(\p{N}+(?:[.,]\p{N}+)*)|(\p{N}+(?:[.,]\p{N}+)*)\s*(?:euros?\b|यूरो|欧元|ユーロ)"#),
            ("rupee", #"₹\s*(\p{N}+(?:[.,]\p{N}+)*)|(\p{N}+(?:[.,]\p{N}+)*)\s*(?:rupees?\b|रुपये|रुपए)"#),
            ("pound", #"£\s*(\p{N}+(?:[.,]\p{N}+)*)"#),
        ]
        var facts: [(Int, String)] = []
        for (unit, pattern) in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let amountRange = match.range(at: 1).location == NSNotFound ? match.range(at: 2) : match.range(at: 1)
                if let range = Range(amountRange, in: text) { facts.append((match.range.location, unit + ":" + text[range])) }
            }
        }
        return facts.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private static func protectedText(in text: String) -> [String] {
        var protected: [String] = []
        // URLs, email addresses and literal quotes must survive grammar editing.
        let pattern = #"https?://[^\s<>]+|[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[\p{L}]{2,}|[\"“「『][^\"”」』]+[\"”」』]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range, in: text) {
                var value = String(text[range])
                if value.hasPrefix("http") {
                    while let last = value.last, ".,;!?。！？".contains(last) { value.removeLast() }
                }
                protected.append(value)
            }
        }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag == .personalName || tag == .placeName || tag == .organizationName {
                protected.append(String(text[range]))
            }
            return true
        }
        return protected
    }

    private static func scripts(in text: String) -> Set<String> {
        var result: Set<String> = []
        for scalar in text.unicodeScalars where CharacterSet.letters.contains(scalar) {
            switch scalar.value {
            case 0x0900...0x097F: result.insert("devanagari")
            case 0x3040...0x30FF: result.insert("kana")
            case 0x3400...0x9FFF, 0xF900...0xFAFF, 0x20000...0x323AF: result.insert("han")
            default: result.insert("other")
            }
        }
        return result
    }

    private static func comparisonUnits(_ text: String) -> [String] {
        // Character comparisons allow Chinese and Japanese particles to change
        // without treating an entire unspaced sentence as one replaced word.
        if !scripts(in: text).isDisjoint(with: ["han", "kana"]) {
            return text.filter { $0.isLetter || $0.isNumber }.map { String($0).lowercased() }
        }
        return TextPassages.words(in: text)
    }

    /// A longest common subsequence, with linear rather than quadratic storage.
    private static func sharedCount(_ lhs: [String], _ rhs: [String]) -> Int {
        var previous = Array(repeating: 0, count: rhs.count + 1)
        for left in lhs {
            var current = Array(repeating: 0, count: rhs.count + 1)
            for (index, right) in rhs.enumerated() {
                current[index + 1] = left == right ? previous[index] + 1 : max(previous[index + 1], current[index])
            }
            previous = current
        }
        return previous.last ?? 0
    }
}
