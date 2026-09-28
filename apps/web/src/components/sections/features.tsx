import { PixelArt } from "@/components/pixel-art";
import { SectionHeading } from "@/components/sections/section-heading";
import { pixelIcons } from "@/lib/pixel-icons";

const features = [
  {
    title: "On-device, always",
    body: "Speech models run on the Neural Engine in your Mac. There is no server to send audio to.",
    icon: pixelIcons.chip,
  },
  {
    title: "Works in every app",
    body: "Mail, Slack, your code editor, a browser tab. Anywhere there's a cursor, your words land there.",
    icon: pixelIcons.cursor,
  },
  {
    title: "Knows where it's typing",
    body: "The pill shows the icon of the app that will receive your text, so you never paste into the wrong window.",
    icon: pixelIcons.target,
  },
  {
    title: "Fast on Apple Silicon",
    body: "Parakeet transcribes a sentence in a fraction of a second, even on the first M1 Macs.",
    icon: pixelIcons.bolt,
  },
  {
    title: "Built for English",
    body: "English-first models handle punctuation, capitalization, and everyday names without extra setup.",
    icon: pixelIcons.letters,
  },
  {
    title: "Leaves your clipboard alone",
    body: "Whatever you had copied is put back right after pasting, and clipboard managers are told to skip the transcript.",
    icon: pixelIcons.clipboard,
  },
];

export function Features() {
  return (
    <section id="features" className="scroll-mt-16 border-t border-line">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="Why LocalBolo" title="Built to disappear into your day." />

        <div className="mt-14 grid gap-px border border-line bg-line sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <div key={feature.title} className="bg-paper p-7 sm:p-8">
              <PixelArt art={feature.icon} className="h-[27px] w-auto text-ink" />
              <h3 className="mt-8 text-xl font-medium tracking-[-0.02em]">{feature.title}</h3>
              <p className="mt-2 text-ink-soft">{feature.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
