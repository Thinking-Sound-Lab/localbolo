import { SectionHeading } from "@/components/sections/section-heading";

const questions = [
  {
    question: "Which Macs does LocalBolo run on?",
    answer:
      "Any Mac with Apple Silicon (M1 or newer) running macOS 15 Sequoia or later. The speech models run on the Neural Engine, which Intel Macs don't have.",
  },
  {
    question: "Does it need an internet connection?",
    answer:
      "Only once, to download the speech model you choose. After that, dictation works completely offline.",
  },
  {
    question: "Why does it need Accessibility access?",
    answer:
      "macOS requires it for two things: noticing when you hold fn while another app is in front, and pasting text at your cursor. LocalBolo only reacts to the fn key and never records what you type.",
  },
  {
    question: "The emoji picker opens when I press fn. How do I stop that?",
    answer:
      "Open System Settings › Keyboard and set “Press 🌐 key to” to “Do Nothing”. LocalBolo's setup guide links straight there.",
  },
  {
    question: "Can it clean up what I say?",
    answer:
      "Yes. Turn on transcript cleanup and a small language model running on your Mac applies your self-corrections and removes filler words, so “9 p.m., sorry, 10 p.m.” becomes “10 p.m.”. It's optional and needs an 880 MB download.",
  },
  {
    question: "Which model should I use?",
    answer:
      "Start with Parakeet v2. It is the fastest and most accurate for English. Try a Whisper model if you'd like a smaller download or prefer its style of punctuation.",
  },
  {
    question: "What languages are supported?",
    answer:
      "LocalBolo is built for English today. Every included model is tuned for English speech.",
  },
];

export function Faq() {
  return (
    <section id="faq" className="scroll-mt-20">
      <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 sm:py-32 lg:grid-cols-[1fr_1.3fr]">
        <SectionHeading eyebrow="FAQ" title="Questions, answered." />

        <div className="divide-y divide-line border-y border-line">
          {questions.map((item) => (
            <details key={item.question} className="group py-5">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-lg font-medium tracking-tight [&::-webkit-details-marker]:hidden">
                {item.question}
                <span
                  aria-hidden
                  className="grid size-7 shrink-0 place-items-center rounded-full border border-line text-ink-soft transition group-open:rotate-45"
                >
                  +
                </span>
              </summary>
              <p className="mt-3 max-w-2xl pr-10 text-ink-soft">{item.answer}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
