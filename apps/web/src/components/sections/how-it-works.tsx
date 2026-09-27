import type { ReactNode } from "react";
import { MailIcon } from "@/components/app-icons";
import { FnKey } from "@/components/fn-key";
import { Pill } from "@/components/pill";
import { SectionHeading } from "@/components/sections/section-heading";

const steps: { title: string; body: string; visual: ReactNode }[] = [
  {
    title: "Hold fn",
    body: "Press and hold the fn key wherever your cursor is. The pill appears with the icon of the app your words will land in.",
    visual: <FnKey isPressed className="scale-125" />,
  },
  {
    title: "Speak naturally",
    body: "Talk the way you would to a colleague. A live waveform shows LocalBolo is listening, and only while you hold the key.",
    visual: <Pill state="listening" icon={<MailIcon />} />,
  },
  {
    title: "Let go",
    body: "Release fn. Your speech is transcribed on-device and pasted right at your cursor, usually in about a second.",
    visual: (
      <p className="max-w-[15rem] rounded-lg border border-line bg-white px-3 py-2 text-left text-sm text-ink shadow-sm">
        Sounds good, see you at three.
        <span className="ml-px inline-block h-[1.1em] w-[2px] translate-y-[3px] animate-pulse bg-ink" />
      </p>
    ),
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="scroll-mt-20">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="How it works" title="Three steps. No typing.">
          Dictation that feels like a keyboard shortcut, not an app you have to open.
        </SectionHeading>

        <ol className="mt-14 grid gap-5 md:grid-cols-3">
          {steps.map((step, index) => (
            <li key={step.title} className="flex flex-col rounded-3xl border border-line bg-white/60 p-6">
              <div className="grid h-40 place-items-center rounded-2xl bg-paper-deep">{step.visual}</div>
              <p className="mt-6 font-mono text-xs text-ink-faint">0{index + 1}</p>
              <h3 className="mt-1 text-xl font-semibold tracking-tight">{step.title}</h3>
              <p className="mt-2 text-ink-soft">{step.body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
