import Link from "next/link";
import { AsciiHover, AsciiText } from "@/components/ascii-hover";
import { BuyButton, SecondaryLink } from "@/components/buy-button";
import { HeroDemo } from "@/components/hero-demo";
import { PixelWave } from "@/components/pixel-wave";
import { site } from "@/lib/site";

export function Hero() {
  return (
    <section className="overflow-hidden">
      <div className="mx-auto flex max-w-6xl flex-col items-center px-6 pt-16 text-center sm:pt-24">
        <Link
          href="/changelog"
          className="group inline-flex items-stretch border border-line text-xs transition-colors hover:border-ink/25"
        >
          <span className="flex items-center gap-2 bg-mist px-3 py-1.5 text-ink-soft">
            <span aria-hidden className="size-1.5 bg-blue" />
            Version 0.1 is out for Mac
          </span>
          <span className="flex items-center border-l border-line px-3 py-1.5 font-medium">
            What&apos;s new ↗
          </span>
        </Link>

        <AsciiHover className="mt-8">
          <h1 className="text-[3.25rem] leading-[0.95] font-medium tracking-[-0.05em] text-balance sm:text-8xl">
            <AsciiText text="Talk, and it " />
            <span className="font-pixel font-normal tracking-[-0.02em] text-blue">
              <AsciiText text="types." />
            </span>
            <br />
            <span className="text-ink-faint">
              <AsciiText text="Nothing leaves your Mac." />
            </span>
          </h1>
        </AsciiHover>

        <p className="mt-8 max-w-xl text-lg text-pretty text-ink-soft">
          Hold <Kbd>fn</Kbd>, speak, and let go. {site.name} turns your voice into clean text in any
          app, with speech models that run entirely on your Mac.
        </p>
        <div className="mt-10 flex flex-col items-center gap-3 sm:flex-row">
          <BuyButton />
          <SecondaryLink href="#how-it-works">See how it works</SecondaryLink>
        </div>
        <p className="mt-6 font-mono text-xs tracking-wide text-ink-faint">
          One-time purchase · {site.requirements}
        </p>
      </div>

      {/* The voice, as a pixel waveform, runs behind the top of the demo. */}
      <div className="relative mt-14 sm:mt-20">
        <PixelWave className="h-48 w-full text-ink [--pixel-accent:var(--color-blue)] sm:h-64" />
        <div className="relative mx-auto -mt-24 max-w-6xl px-4 pb-20 sm:-mt-32 sm:px-6 sm:pb-24">
          <HeroDemo />
        </div>
      </div>
    </section>
  );
}

function Kbd({ children }: { children: string }) {
  return (
    <kbd className="mx-0.5 inline-flex -translate-y-px items-center border border-ink bg-white px-1.5 py-0.5 font-mono text-[0.8em] text-ink shadow-[0_2px_0_var(--color-ink)]">
      {children}
    </kbd>
  );
}
