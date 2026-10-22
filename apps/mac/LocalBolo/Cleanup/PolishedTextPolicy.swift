import Foundation
import NaturalLanguage

/// Checks for obvious factual changes and unrelated output. These checks do not
/// prove semantic equivalence; the original passage remains the fallback.
nonisolated enum PolishedTextPolicy {
    static func accepts(_ edited: String, original: String, language: String?) -> Bool {
        let edited = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !edited.isEmpty, !hasWrapper(edited), edited.count <= original.count * 2 + 80 else { return false }

        // Retain the established, stricter policy for explicit English corrections.
        // It compares words and ignores punctuation, so links, quotes, names and
        // amounts in the edit must still be the speaker's own, unchanged.
        if language == "en", TranscriptEditPolicy.isFaithful(edited, to: original) {
            let editedNumbers = numbers(in: edited)
            let editedCurrencies = currencies(in: edited)
            // A taken-back amount may go, but one that stays keeps its currency.
            let keptAmounts = currencies(in: original).filter { fact in
                fact.split(separator: ":").last.map { editedNumbers.contains(String($0)) } ?? false
            }
            return protectedText(in: edited).allSatisfy { original.localizedCaseInsensitiveContains($0) }
                && isSubsequence(editedNumbers, of: numbers(in: original))
                && isSubsequence(editedCurrencies, of: currencies(in: original))
                && isSubmultiset(keptAmounts, of: editedCurrencies)
        }

        // Facts are compared with what the speaker kept after correcting themselves.
        let reference = withoutTakenBack(original, editedTo: edited)
        guard currencies(in: edited) == currencies(in: reference),
              numbers(in: edited) == numbers(in: reference),
              wordFacts(in: edited) == wordFacts(in: reference),
              negations(in: edited) == negations(in: reference),
              protectedText(in: reference).allSatisfy({ edited.localizedCaseInsensitiveContains($0) }),
              protectedText(in: edited).allSatisfy({ original.localizedCaseInsensitiveContains($0) }),
              scripts(in: edited).isSubset(of: scripts(in: original)) else { return false }

        let listCues: Set<String> = ["first", "second", "third", "fourth", "fifth", "firstly", "secondly", "thirdly"]
        let hasList = edited.contains(/\n\s*[-•]\s/)
        let comparisonOriginal = edited.contains("\n") ? removingParagraphCues(reference) : reference
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

    // MARK: - Spoken corrections

    /// The original without what the speaker took back, as the edit shows it.
    ///
    /// A stretch the edit dropped counts as taken back if it ends with a
    /// correction phrase said after something else, give or take a couple of
    /// words restarting the sentence: "明天9点见，不对，10点见" loses "9点见，不对".
    /// The correction itself must survive in the edit. An edit that keeps the
    /// withdrawn version instead is compared with all of the original.
    private static func withoutTakenBack(_ original: String, editedTo edited: String) -> String {
        let cues = correctionCues(in: original)
        guard !cues.isEmpty else { return original }
        let characters = !scripts(in: original).isDisjoint(with: ["han", "kana"])
        let before = units(in: original, characters: characters)
        let kept = latestMatches(before.map(\.text), units(in: edited, characters: characters).map(\.text))

        var result = ""
        var cursor = original.startIndex
        var index = 0
        while index < before.count {
            guard !kept.contains(index) else { index += 1; continue }
            var end = index
            while end + 1 < before.count, !kept.contains(end + 1) { end += 1 }
            let dropped = before[index...end]
            let run = dropped.first!.range.lowerBound..<dropped.last!.range.upperBound
            let takenBack = cues.contains { cue in
                guard run.lowerBound < cue.lowerBound, cue.upperBound <= run.upperBound else { return false }
                let restart = dropped.filter { $0.range.lowerBound >= cue.upperBound }
                guard restart.count <= 2, !restart.contains(where: { $0.text.contains(where: \.isNumber) }) else { return false }
                return survives(String(original[cue.upperBound..<sentenceEnd(after: cue.upperBound, in: original)]), in: edited)
            }
            if takenBack {
                result += original[cursor..<run.lowerBound]
                cursor = run.upperBound
            }
            index = end + 1
        }
        return result + original[cursor...]
    }

    /// Phrases that take back what was just said, after a pause. Those that are
    /// also ordinary words, like "no", "不是" or "नहीं", need a pause after them too.
    private static func correctionCues(in text: String) -> [Range<String.Index>] {
        let pause = #"[,，、。.!?！？;；:：।…—–]"#
        let firm = ["sorry", "i mean", "i meant", "scratch that", "strike that", "make that", "or rather", "correction",
                    "oops", "no wait", "no no", "不对", "说错了", "我是说", "我的意思是", "更正", "じゃなくて", "間違えた",
                    "違います", "訂正", "नहीं नहीं", "मतलब", "माफ़ कीजिए", "माफ़ करना", "सॉरी"]
        let ambiguous = ["no", "actually", "wait", "rather", "不是", "いや", "違う", "नहीं"]
        let boundary = #"(?![\p{Latin}\p{Devanagari}])"#
        let pattern = "(?:^|\(pause))\\s*(\(firm.joined(separator: "|")))\(boundary)"
            + "|(?:^|\(pause))\\s*(\(ambiguous.joined(separator: "|")))\(boundary)(?=\\s*\(pause))"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            let group = match.range(at: 1).location == NSNotFound ? match.range(at: 2) : match.range(at: 1)
            return Range(group, in: text)
        }
    }

    private static func sentenceEnd(after position: String.Index, in text: String) -> String.Index {
        text[position...].firstRange(of: /[。！？!?।\n]|\.(?=\s|$)/)?.lowerBound ?? text.endIndex
    }

    /// Whether the facts of a spoken correction all appear in the edit.
    private static func survives(_ correction: String, in edited: String) -> Bool {
        isSubmultiset(numbers(in: correction), of: numbers(in: edited))
            && isSubmultiset(currencies(in: correction), of: currencies(in: edited))
            && isSubmultiset(wordFacts(in: correction), of: wordFacts(in: edited))
            && negations(in: correction) <= negations(in: edited)
            && protectedText(in: correction).allSatisfy { edited.localizedCaseInsensitiveContains($0) }
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
        units(in: text, characters: !scripts(in: text).isDisjoint(with: ["han", "kana"])).map(\.text)
    }

    /// Words, or for Chinese and Japanese single characters, so particles can
    /// change without treating an entire unspaced sentence as one replaced word.
    private static func units(in text: String, characters: Bool) -> [(text: String, range: Range<String.Index>)] {
        if characters {
            return text.indices.compactMap { index in
                let character = text[index]
                guard character.isLetter || character.isNumber else { return nil }
                return (String(character).lowercased(), index..<text.index(after: index))
            }
        }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).compactMap { range in
            let word = String(text[range]).lowercased()
            return word.contains(where: { $0.isLetter || $0.isNumber }) ? (word, range) : nil
        }
    }

    /// Positions in `lhs` of a longest common subsequence with `rhs`, matched
    /// as late in `lhs` as possible, because a correction keeps the later version.
    private static func latestMatches(_ lhs: [String], _ rhs: [String]) -> Set<Int> {
        let width = rhs.count + 1
        var lengths = [UInt16](repeating: 0, count: (lhs.count + 1) * width)
        for i in lhs.indices {
            for j in rhs.indices {
                lengths[(i + 1) * width + j + 1] = lhs[i] == rhs[j]
                    ? lengths[i * width + j] + 1
                    : max(lengths[i * width + j + 1], lengths[(i + 1) * width + j])
            }
        }
        var matches: Set<Int> = []
        var i = lhs.count
        var j = rhs.count
        while i > 0, j > 0 {
            if lhs[i - 1] == rhs[j - 1] {
                matches.insert(i - 1)
                i -= 1
                j -= 1
            } else if lengths[(i - 1) * width + j] >= lengths[i * width + j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return matches
    }

    private static func isSubsequence<T: Equatable>(_ items: [T], of sequence: [T]) -> Bool {
        var rest = sequence[...]
        for item in items {
            guard let index = rest.firstIndex(of: item) else { return false }
            rest = rest[rest.index(after: index)...]
        }
        return true
    }

    private static func isSubmultiset(_ items: [String], of collection: [String]) -> Bool {
        var counts = Dictionary(collection.map { ($0, 1) }, uniquingKeysWith: +)
        for item in items {
            guard let count = counts[item], count > 0 else { return false }
            counts[item] = count - 1
        }
        return true
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
