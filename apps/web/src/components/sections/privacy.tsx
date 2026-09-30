import Link from "next/link";
import { PixelEdge } from "@/components/pixel-edge";
import { Eyebrow } from "@/components/sections/section-heading";

const zeros = ["Servers", "Accounts", "Recordings kept"];

const facts = [
  {
    title: "No servers",
    body: "There is no LocalBolo cloud. Audio is transcribed by a model running on your Mac.",
  },
  {
    title: "No account",
    body: "Enter your license key, allow microphone and accessibility access, and start talking.",
  },
  {
    title: "Nothing is kept",
    body: "Recordings live in memory only while they're transcribed, then they're gone.",
  },
  {
    title: "Only listens on fn",
    body: "The microphone turns on when you hold fn and turns off the moment you let go.",
  },
];

export function Privacy() {
  return (
    <section id="privacy" className="scroll-mt-16">
      <PixelEdge seed={7} className="text-ink" />
      <div className="bg-ink text-white pixel-grid [--pixel-color:rgb(255_255_255/0.08)]">
        <div className="mx-auto max-w-6xl px-6 py-20 sm:py-28">
          <Eyebrow className="text-white/60">Privacy</Eyebrow>
          <h2 className="mt-5 max-w-3xl text-4xl leading-[0.98] font-medium tracking-[-0.04em] text-balance sm:text-6xl">
            Your voice stays on your Mac. <span className="text-white/45">Full stop.</span>
          </h2>

          <dl className="mt-16 grid grid-cols-3 gap-4 border-y border-white/10 py-10">
            {zeros.map((label) => (
              <div key={label} className="flex flex-col-reverse justify-end gap-4">
                <dt className="font-mono text-xs tracking-[0.14em] text-white/60 uppercase">{label}</dt>
                <dd className="font-pixel text-7xl leading-none text-blue-soft sm:text-9xl">0</dd>
              </div>
            ))}
          </dl>

          <div className="mt-12 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
            {facts.map((fact) => (
              <div key={fact.title}>
                <h3 className="text-lg font-medium tracking-[-0.02em]">{fact.title}</h3>
                <p className="mt-2 text-white/65">{fact.body}</p>
              </div>
            ))}
          </div>

          <Link
            href="/privacy"
            className="mt-14 inline-block text-sm text-white/70 underline underline-offset-4 transition-colors hover:text-white"
          >
            Read exactly what LocalBolo does with your data
          </Link>
        </div>
      </div>
      <PixelEdge seed={11} flip className="text-ink" />
    </section>
  );
}
