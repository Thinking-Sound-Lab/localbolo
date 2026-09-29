import { ChatIcon } from "@/components/app-icons";
import { BuyButton } from "@/components/buy-button";
import { Pill } from "@/components/pill";
import { PixelCascade } from "@/components/pixel-cascade";
import { PixelEdge } from "@/components/pixel-edge";
import { site } from "@/lib/site";

export function FinalCta() {
  return (
    <section>
      <PixelEdge seed={23} className="text-ink" />
      <div className="relative overflow-hidden bg-ink text-white pixel-grid [--pixel-color:rgb(255_255_255/0.08)]">
        <div className="relative z-10 mx-auto flex max-w-6xl flex-col items-center px-6 pt-20 pb-40 text-center sm:pt-28 sm:pb-64">
          <Pill state="listening" icon={<ChatIcon />} />
          <h2 className="mt-10 text-5xl leading-[0.95] font-medium tracking-[-0.045em] text-balance sm:text-7xl">
            Give your keyboard a break.
          </h2>
          <p className="mt-6 max-w-md text-lg text-white/65">
            Setup takes a minute. After that, it&apos;s just you, the fn key, and your voice.
          </p>
          <BuyButton tone="white" className="mt-10" />
          <p className="mt-5 font-mono text-xs tracking-wide text-white/55">
            One-time purchase · {site.requirements}
          </p>
        </div>
        <PixelCascade seed={5} className="absolute inset-x-0 bottom-0" />
      </div>
    </section>
  );
}
