import { site } from "@/lib/site";

/** Frequently asked questions, shown on the home page and published as structured data. */
export const faq: { question: string; answer: string }[] = [
  {
    question: "How much does LocalBolo cost?",
    answer: `${site.price.label}, once. There's no subscription, and because dictation runs on your Mac, there are no word limits or minutes to count.`,
  },
  {
    question: "Can I get a refund?",
    answer: `Yes. If LocalBolo isn't right for you, email us within ${site.refundDays} days of buying it for a full refund, no questions asked.`,
  },
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
    question: "Which speech model should I use?",
    answer:
      "Start with Parakeet v2. It is the fastest and most accurate for English. Try a Whisper model if you'd like a smaller download or prefer its style of punctuation.",
  },
  {
    question: "What languages are supported?",
    answer:
      "LocalBolo is built for English today. Every included model is tuned for English speech.",
  },
];
