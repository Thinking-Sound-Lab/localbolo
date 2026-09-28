import type { ReactNode } from "react";
import { MailIcon } from "@/components/app-icons";
import { Card, Frame } from "@/components/card";
import { FnKey } from "@/components/fn-key";
import { Pill } from "@/components/pill";
import { SectionHeading } from "@/components/sections/section-heading";

const steps: { title: string; body: string; visual: ReactNode }[] = [
  {
    title: "Hold fn",
    body: "Press and hold the fn key wherever your cursor is. The pill appears with the icon of the app your words will land in.",
    visual: <FnKey isPressed className="scale-150" />,
  },
  {
    title: "Speak naturally",
    body: "Talk the way you would to a colleague. The waveform shows LocalBolo is listening, and it only listens while you hold the key.",
    visual: <Pill state="listening" icon={<MailIcon />} />,
  },
  {
    title: "Let go",
    body: "Release fn. Your speech is transcribed on your Mac and pasted right at your cursor, usually in about a second.",
    visual: (
      <p className="max-w-[14rem] border border-line bg-white px-3 py-2 text-left text-sm text-ink shadow-[0_2px_0_var(--color-line)]">
        Sounds good, see you at three.
        <span className="ml-px inline-block h-[1.1em] w-[2px] translate-y-[3px] bg-blue motion-safe:animate-blink" />
      </p>
    ),
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="scroll-mt-16 border-t border-line">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="How it works" title="Three steps. No typing.">
          Dictation that feels like a keyboard shortcut, not an app you have to open.
        </SectionHeading>

        <ol className="mt-14 grid gap-4 md:grid-cols-3">
          {steps.map((step, index) => (
            <li key={step.title} className="flex">
              <Card title={step.title} index={index + 1} className="flex-1">
                <Frame className="mt-6 h-52">{step.visual}</Frame>
                <p className="mt-6 text-ink-soft">{step.body}</p>
              </Card>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
