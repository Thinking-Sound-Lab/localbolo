import { DownloadButton } from "@/components/download-button";
import { HeroDemo } from "@/components/hero-demo";
import { site } from "@/lib/site";

export function Hero() {
  return (
    <section className="overflow-hidden">
      <div className="mx-auto max-w-6xl px-6 pt-16 pb-12 text-center sm:pt-24">
        <p className="inline-flex items-center gap-2 rounded-full border border-line bg-white/60 px-3 py-1 text-xs font-medium text-ink-soft">
          <span className="size-1.5 rounded-full bg-emerald-500" />
          Runs entirely on your Mac
        </p>
        <h1 className="mx-auto mt-6 max-w-4xl font-display text-6xl leading-[0.95] tracking-tight text-balance sm:text-8xl">
          Talk, and it types.
          <br />
          <span className="text-ink-soft italic">Nothing leaves your Mac.</span>
        </h1>
        <p className="mx-auto mt-7 max-w-xl text-lg text-pretty text-ink-soft">
          Hold <Kbd>fn</Kbd>, speak, and let go. {site.name} turns your voice into clean text in
          any app, using models that run entirely on your Mac.
        </p>
        <div className="mt-9 flex flex-col items-center justify-center gap-4 sm:flex-row">
          <DownloadButton />
          <a
            href="#how-it-works"
            className="rounded-full px-5 py-3.5 font-medium text-ink-soft transition hover:text-ink"
          >
            See how it works →
          </a>
        </div>
        <p className="mt-4 text-sm text-ink-faint">{site.requirements}</p>
      </div>

      <div className="mx-auto max-w-6xl px-4 pb-20 sm:px-6 sm:pb-28">
        <HeroDemo />
      </div>
    </section>
  );
}

function Kbd({ children }: { children: string }) {
  return (
    <kbd className="mx-0.5 inline-flex -translate-y-px items-center rounded-md border border-line bg-white px-1.5 py-0.5 font-sans text-[0.85em] font-medium text-ink shadow-[0_1px_0_var(--color-line)]">
      {children}
    </kbd>
  );
}
