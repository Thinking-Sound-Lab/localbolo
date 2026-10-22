# Dictation performance on an 8 GB M1

Measured on 22 October 2026 using an Apple M1 MacBook Pro (`MacBookPro17,1`),
8 GB unified memory, macOS 27.0.1 and Xcode 27.1. The Mac was in everyday use:
other applications stayed open and about 6 GB of swap was in use. This is a
same-machine comparison, not a laboratory benchmark. Every recorded thermal
state was nominal.

The baseline is commit `edf20a6`. Both builds run the same benchmark harness, models,
recordings and decoding settings.

## Results

| Scenario | Before | After |
| --- | ---: | ---: |
| Auto language, Japanese speech, back to back | 3.58 s | 2.00 s (−44%) |
| Editing after a change of language | 2.01–2.19 s | 0.44–0.62 s (−72% to −78%) |
| Japanese after 45 s idle, recognition and polishing | 2.34 s (worst 2.83 s) | 1.79 s (worst 2.29 s) |
| Whisper dictation of a second or less | Nothing pasted | Transcribed |
| One language back to back: English, Chinese, Hindi, Japanese | 0.28 / 2.04 / 2.66 / 1.77 s | Unchanged within noise |
| Memory | 2.37 GB footprint, 1.35 GB MLX peak | Unchanged |

Times are medians from the end of recording until the finished text is ready.
Recording, the fn hold, paste delivery and the destination application are excluded.

### Where the time goes now

| Stage | Cost |
| --- | --- |
| Parakeet v2, English, about 6 s of audio | 0.12 s |
| Conservative English cleanup | 0.16 s |
| Whisper Turbo encoder, any length up to 30 s | 0.95 s, fixed |
| Whisper Turbo decoder | 14 ms per token: Chinese 30, Japanese 26, Hindi 55 for a short sentence |
| Polished edit, short sentence to 60 words | 0.22–0.65 s |

Speech recognition is 70–80% of every non-English dictation, and most of that
is the encoder. Whisper always encodes a 30-second window, so a 2-second dictation
costs the same as a 25-second one. Hindi decodes about twice as many tokens as
Chinese or Japanese for the same sentence, which makes it the slowest language.

## Changes

1. **Language changes reuse the editing prompt.** The Polished rules and examples
   no longer depend on the language. A short language hint now comes last. A
   language change rewinds the one prompt cache to the shared prefix and reads only
   the new hint, instead of the whole prompt again (about 2 s).
2. **Auto mode warms up for the language it last detected.** Before, every Auto
   dictation warmed the "Auto" prompt, then switched to the detected language
   before editing. That switch cost about 1.8 s after recording on every dictation.
   Auto remains about 0.3 s slower than selecting Japanese. Language detection adds
   about 0.1 s to recognition. The edit itself is the same work, but its timing
   varied more in these runs, which the code path doesn't explain.
3. **Whisper transcribes short recordings.** WhisperKit skips any audio no longer
   than its one-second `windowClipTime`, so a quick "はい" or "हाँ" came back empty.
   Recordings are now padded with silence to just over a second. Whisper pads
   every window to 30 seconds of silence anyway, so the encoder input is identical.
4. **Whisper's warm-up runs the model.** The warm-up transcribed a second of silence,
   which WhisperKit skipped for the same reason, so Whisper was never woken while
   fn was held. After 45 s idle, recognition took 1.96 s instead of 1.40 s. The
   warm-up now decodes a single token without temperature fallbacks. It is skipped
   if Whisper ran in the last 15 seconds, so a quick follow-up doesn't queue behind
   it.
5. **The editor's warm-up stays a full short edit.** A single forward pass was tried.
   It saves about 200 ms of work while the user is still speaking. After idle, it
   left the next edit slower (median 0.49 s against 0.41 s, worst 0.82 s against
   0.63 s), because it doesn't wake the tokenizer or decoding path.

Prompt preparation also checks for cancellation and keeps its cache bookkeeping
valid if it is interrupted. Model sizes, greedy decoding, passage bounds and the
meaning-preservation checks are unchanged.

### Output changes

Across 20 runs of each case, every output was identical except one Polished
Chinese edit: `明天我们要开会请带上电脑` now becomes `明天我们要开会，请带上电脑。`
instead of `明天我们要开会。请带上电脑。`. Both pass validation. Mixed Hindi and
English keeps English punctuation (`… Please send the agenda.`).

## Spoken corrections in Polished mode

The Polished prompt asked the model to apply spoken self-corrections, but it gave
no examples. On a held-out set of 15 corrections and 9 controls, Qwen 3 1.7B
applied none. The set is `LocalBoloTests/PolishedCorrectionEvaluation.json`,
run by `evaluatesSpokenCorrections()`. Corrections span Chinese, Japanese, Hindi,
mixed Hindi-English and English. Controls use the same words without correcting
anything, as in "这不是问题", "彼は違う会社に行きました", "मैं नहीं आऊंगा" or "No, I don't
want coffee". A unit test checks the prompt never contains an evaluation dictation.

A correction is **applied** when only the final version is pasted, **kept** when
both versions are (safe, but not what was asked), and **lost** when the final
version is missing. Every variant kept all nine controls intact.

| Prompt | Applied | Lost | Other held-out checks |
| --- | ---: | ---: | --- |
| Before (no correction examples) | 0 / 15 | 0 | Pass |
| A: rule naming cue words, 4 correction examples and 1 control | 5 / 15 | 1 before the policy fix below | Not run |
| B: A, plus "the words after the phrase replace the words before it" and 2 more examples | 9 / 15 | 0 | "New paragraph" deleted instead of becoming a blank line |
| C–E: example order and wording changes | 7–9 / 15 | 0 | Same paragraph failure |
| **F (shipped): B with the examples first, plus a second paragraph example** | **8 / 15** | **0** | **Pass** |

Applied by language in F: Chinese 3 of 4, Japanese 2 of 4, Hindi 2 of 5 (one of
them mixed with English), English 1 of 2. When the model gets a correction
wrong, it usually keeps the withdrawn version and drops the final one. Variant A
showed the policy accepting one such edit, so two rules were added:

- The correction, the rest of its sentence after the cue, must survive word for
  word. A shared ending such as "さんに" can no longer hide a dropped "佐藤".
- A correction phrase may only disappear together with what it takes back.
  Deleting "说错了" while keeping both days hides which was meant.

The new examples also made the model more willing to delete. In the benchmark,
`明日の朝、会社で会議があります。` lost `会社で`. Chinese, Japanese and Hindi had
no content-word check like English's, so the policy now rejects an edit that
drops more than two characters, or more than one word, without writing anything
in its place. Filler, stammers, formatting cues and taken-back corrections are
exempt. With that guard, every benchmark output matches the previous prompt.

The longer prompt makes each Polished edit 4–8% slower, 15–35 ms, across
20 alternating samples per case. Peak MLX memory rose 73 MB, to 1.42 GB. The
extra prompt is read once when the model loads; a language change still rereads
only the short hint. English conservative cleanup uses a different prompt and is
unchanged.

## Measured and rejected

| Experiment | Result |
| --- | --- |
| Whisper encoder on the GPU | 3.7× slower than the Neural Engine |
| Whisper decoder on the GPU | 4.8× slower per token (70 ms against 14 ms) |
| Whisper without VAD chunking | No difference for audio under 30 s |
| Single forward pass as the editor warm-up | Slower edits after idle (see above) |

WhisperKit's defaults are already the fastest on this Mac. No decoding setting
removes the fixed encoder cost.

## Trade-offs and open questions

- **Whisper warm-up and very short holds.** A warm-up costs about 1 s of Neural
  Engine time, and up to 3 s after a long idle. If fn is released before it
  finishes, transcription waits for it. That is about what waking a cold model
  would have cost anyway. Within 15 seconds of the last dictation it is skipped.
  After 14 s idle, Whisper was only about 0.2 s slower than when warm.
- **Faster non-English recognition needs a different model or streaming.** Options
  include a smaller multilingual encoder, a language-specific model, or
  transcribing while the user speaks. Each needs accuracy testing per language.
- **Recordings are synthetic.** They come from macOS voices, not native speakers,
  microphones or rooms. Accuracy figures here are fixture checks, not a quality
  benchmark. Hindi recognition remains noticeably weaker.

## Method

`PerformanceBenchmarks` is opt-in and serial and uses already-installed models.
English uses Parakeet v2 with Qwen 2.5 1.5B conservative cleanup. Other languages
use Whisper Large v3 Turbo with Qwen 3 1.7B Polished mode. The pipeline test calls
the app's own `TranscriptCleanup` warm-up and cleanup path. Each speech condition
runs ten times per run, back to back, after the warm-ups that run while fn is held.
Text-only cases cover English grammar, a longer English passage, Chinese, Hindi,
Japanese and mixed Hindi-English, then alternate languages to measure switching.

Builds were run in the order baseline, optimized, optimized, baseline, and pooled,
giving 20 samples per condition. Idle measurements wait 45 s before each dictation
and alternate between running the app's warm-ups and running none. That is five
dictations per strategy for the baseline and ten for the optimized build. p95 is
nearest rank. Memory figures are `task_info` physical footprint and MLX counters
sampled after each stage. They can miss short peaks and exclude other processes.

Recordings are synthesized once with macOS voices as 16 kHz mono audio:

| Condition | Audio length | Voice |
| --- | ---: | --- |
| English | 5.82 s | Samantha |
| Mandarin Chinese | 5.50 s | Tingting |
| Hindi | 3.52 s | Lekha |
| Japanese, and Auto with Japanese audio | 4.99 s | Kyoko |

Raw samples for the back-to-back comparison, including output hashes, are in
`docs/benchmarks/m1-2026-10-22.csv`.

## Reproduce

Install Parakeet v2, Whisper Turbo, Qwen 2.5 1.5B and Qwen 3 1.7B through Settings,
and quit other LocalBolo instances. From `apps/mac`, with a label per run:

```sh
TEST_RUNNER_LOCALBOLO_BENCHMARKS=1 \
TEST_RUNNER_LOCALBOLO_BENCHMARK_DIRECTORY="$PWD/../../.context/benchmarks" \
TEST_RUNNER_LOCALBOLO_BENCHMARK_LABEL=optimized \
xcodebuild test -project LocalBolo.xcodeproj -scheme 'LocalBolo Dev' \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO '-only-testing:LocalBoloTests/PerformanceBenchmarks/dictationPipeline()' \
  -quiet ENABLE_TESTABILITY=YES ENABLE_HARDENED_RUNTIME=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS=
```

`TEST_RUNNER_LOCALBOLO_BENCHMARK_REPETITIONS` accepts 3–30 (default 10). Select
`idleWake()` for the idle comparison, with `TEST_RUNNER_LOCALBOLO_BENCHMARK_IDLE_SECONDS`
(default 45). Select `whisperStages()` for Whisper's stage timings and compute-unit
comparison. The signing overrides apply only to the local test run.

From the repository root, compare builds, pooling repeated runs:

```sh
python3 scripts/summarize-dictation-benchmarks.py \
  --before .context/benchmarks/baseline-a.json .context/benchmarks/baseline-b.json \
  --after .context/benchmarks/optimized-a.json .context/benchmarks/optimized-b.json
```
