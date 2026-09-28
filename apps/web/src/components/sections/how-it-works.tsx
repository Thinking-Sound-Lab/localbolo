import type { ReactNode } from "react";
import { MailIcon } from "@/components/app-icons";
import { FnKey } from "@/components/fn-key";
import { Pill } from "@/components/pill";
import { SectionHeading } from "@/components/sections/section-heading";
import { cx } from "@/lib/cx";

/** Each step is a tile in one of the site's three colors. */
const tones = {
  light: { tile: "bg-white text-ink dot-grid [--dot-color:rgb(31_61_255/0.16)]", muted: "text-ink-soft" },
  blue: { tile: "bg-blue text-white dot-grid [--dot-color:rgb(255_255_255/0.22)]", muted: "text-white/75" },
  dark: { tile: "bg-ink text-white dot-grid [--dot-color:rgb(255_255_255/0.12)]", muted: "text-white/65" },
};

const steps: { title: string; body: string; visual: ReactNode; tone: keyof typeof tones }[] = [
  {
    title: "Hold fn",
    body: "Press and hold the fn key wherever your cursor is. The pill appears with the icon of the app your words will land in.",
    visual: <FnKey isPressed className="scale-150" />,
    tone: "light",
  },
  {
    title: "Speak naturally",
    body: "Talk the way you would to a colleague. The waveform shows LocalBolo is listening, and it only listens while you hold the key.",
    visual: <Pill state="listening" icon={<MailIcon />} />,
    tone: "blue",
  },
  {
    title: "Let go",
    body: "Release fn. Your speech is transcribed on your Mac and pasted right at your cursor, usually in about a second.",
    visual: (
      <p className="max-w-[15rem] border border-white/20 bg-ink px-3 py-2 text-left font-mono text-sm text-white">
        Sounds good, see you at three.
        <span className="ml-px inline-block h-[1.1em] w-[2px] translate-y-[3px] motion-safe:animate-blink bg-blue-soft" />
      </p>
    ),
    tone: "dark",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="scroll-mt-16">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="How it works" title="Three steps. No typing.">
          Dictation that feels like a keyboard shortcut, not an app you have to open.
        </SectionHeading>

        <ol className="mt-14 grid gap-4 md:grid-cols-3">
          {steps.map((step, index) => (
            <li key={step.title} className={cx("p-6 sm:p-7", tones[step.tone].tile)}>
              <p className="font-mono text-xs tracking-[0.14em] opacity-70">0{index + 1}</p>
              <div className="grid h-52 place-items-center">{step.visual}</div>
              <h3 className="text-2xl font-medium tracking-[-0.03em]">{step.title}</h3>
              <p className={cx("mt-2", tones[step.tone].muted)}>{step.body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
