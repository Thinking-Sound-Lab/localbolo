# Multilingual dictation validation

Checked on an Apple M1 Mac with 8 GB RAM, macOS 27.0.1 and Xcode 27.1.
These are integration fixtures, not a native-speaker accuracy benchmark.

Downloaded model revisions used for this run:

- `argmaxinc/whisperkit-coreml`: `0f63a7800b00dd0226abd051b906c246e1907482`
- `mlx-community/Qwen3-1.7B-4bit`: `3b1b1768f8f8cf8351c712464f906e86c2b8269e`

## Recognition and editing

`MultilingualIntegrationTests` loads the real Whisper Turbo and Qwen 3 1.7B models.
It synthesizes speech using macOS Tingting, Lekha and Kyoko, checks selected-language
recognition and automatic Japanese detection, then runs the transcription through
the same cleanup processor used by dictation. Held-out text fixtures check grammar,
plain-text lists, blank-line paragraphs, mixed Hindi/English, and retained amounts
and negation. Unsupported or rejected edits keep the original passage.

Examples observed with the real editor:

| Input | Output |
| --- | --- |
| she have two meeting tomorrow | She has two meetings tomorrow. |
| 明天我们要开会请带上电脑 | 明天我们要开会，请带上电脑。 |
| रीना ने मुझे किताब दिया | रीना ने मुझे किताब दी। |
| 私は昨日映画を見ますた | 私は昨日映画を見ました。 |
| आज team meeting है please send the agenda | आज team meeting है। Please send the agenda. |

The list fixture became three `- ` lines. “New paragraph” became a blank-line
paragraph break. Equivalent currency formatting, such as `250 dollars` → `$250`,
passes checks; changing `$250` to `€250` does not.

## Limits found during validation

- Hindi recognition is imperfect in the synthetic fixture. The spoken
  `कृपया रिपोर्ट भेज दें` was recognized as `क्रिपिया रिपोर्ट घेज गें`; polishing
  added punctuation but did not repair those lexical recognition errors.
- The recognition assertions check language and key content, not a WER/CER
  threshold. Natural speech, accents, noise, and mixed-language **audio** still
  need evaluation with native speakers. The mixed-language editor test starts
  from text, so it does not establish mixed-language recognition quality.
- Content checks catch obvious changes to numbers, currencies, dates, names,
  negation and English content words. They do not prove semantic equivalence.
- One observed run used about 1.06 GB active MLX memory, a 34 MB reusable buffer
  cache, and 1.35 GB peak MLX memory. These figures exclude Core ML and the rest
  of the application, and are not a guarantee of whole-process memory use.
- In the latest run, short recognition fixtures took roughly 1.4–1.9 seconds and
  each text fixture took about 0.5–0.6 seconds, including a change of language.
  These are individual observations. See `dictation-performance.md` for repeated
  measurements. Dictation warms both models while fn is held.
- A 0.4-second Japanese reply (“はい”) is recognized. WhisperKit skips audio of a
  second or less, so recordings that short are padded with silence.

## Reproduce

Run the ordinary Mac tests as documented in `AGENTS.md`. Run the opt-in
`MultilingualIntegrationTests` separately from the existing model integration
suites on an 8 GB Mac; see the README for the command. The downloaded models
are shared with the app, but test preferences use separate UserDefaults suites.

Before broadening language claims, collect consented recordings and native-speaker
reviews for Mandarin, Hindi, Japanese, English and code-switching. Measure
recognition errors, grammar and punctuation quality, meaning preservation,
release-to-paste latency, and idle/peak process memory separately.
