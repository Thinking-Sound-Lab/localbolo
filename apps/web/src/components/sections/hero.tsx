import { BuyButton } from "@/components/buy-button";
import { DotWave } from "@/components/dot-wave";
import { HeroDemo } from "@/components/hero-demo";
import { Eyebrow } from "@/components/sections/section-heading";
import { site } from "@/lib/site";

export function Hero() {
  return (
    <section className="overflow-hidden">
      <div className="mx-auto flex max-w-6xl flex-col items-center px-6 pt-20 text-center sm:pt-28">
        <Eyebrow>On-device dictation for Mac</Eyebrow>
        <h1 className="mt-7 text-[3.25rem] leading-[0.92] font-medium tracking-[-0.05em] text-balance sm:text-8xl">
          Talk, and it <span className="font-pixel font-normal tracking-[-0.02em] text-blue">types.</span>
          <br />
          <span className="text-ink-faint">Nothing leaves your Mac.</span>
        </h1>
        <p className="mt-8 max-w-xl text-lg text-pretty text-ink-soft">
          Hold <Kbd>fn</Kbd>, speak, and let go. {site.name} turns your voice into clean text in any
          app, with speech models that run entirely on your Mac.
        </p>
        <div className="mt-10 flex flex-col items-center gap-5 sm:flex-row">
          <BuyButton />
          <a
            href="#how-it-works"
            className="text-sm font-medium text-ink-soft underline-offset-4 transition-colors hover:text-ink hover:underline"
          >
            See how it works
          </a>
        </div>
        <p className="mt-6 font-mono text-xs tracking-wide text-ink-faint">
          One-time purchase · {site.requirements}
        </p>
      </div>

      {/* The voice, as a dot-matrix waveform, runs behind the top of the demo. */}
      <div className="relative mt-14 sm:mt-20">
        <DotWave className="h-48 w-full text-ink [--dot-accent:var(--color-blue)] sm:h-64" />
        <div className="relative mx-auto -mt-24 max-w-6xl px-4 pb-20 sm:-mt-32 sm:px-6 sm:pb-28">
          <HeroDemo />
        </div>
      </div>
    </section>
  );
}

function Kbd({ children }: { children: string }) {
  return (
    <kbd className="mx-0.5 inline-flex -translate-y-px items-center rounded-md border border-ink bg-white px-1.5 py-0.5 font-mono text-[0.8em] text-ink shadow-[0_2px_0_var(--color-ink)]">
      {children}
    </kbd>
  );
}
