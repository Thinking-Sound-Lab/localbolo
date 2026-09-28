import { BuyButton } from "@/components/buy-button";
import { PixelArt } from "@/components/pixel-art";
import { SectionHeading } from "@/components/sections/section-heading";
import { pixelIcons } from "@/lib/pixel-icons";
import { site } from "@/lib/site";

const included = [
  "Unlimited dictation in every app",
  "Every speech model: Parakeet and Whisper",
  "On-device transcript cleanup",
  "Works offline after setup",
  "No account, no subscription",
];

export function Pricing() {
  return (
    <section id="pricing" className="scroll-mt-16 border-t border-line">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="Pricing" title="Pay once. Talk as much as you like.">
          No subscription and no word limits. Your Mac does the work, so there&apos;s nothing to
          meter.
        </SectionHeading>

        <div className="mt-14 grid bg-blue text-white dot-grid [--dot-color:rgb(255_255_255/0.2)] md:grid-cols-2">
          <div className="flex flex-col p-8 sm:p-12">
            <p className="font-mono text-xs tracking-[0.14em] text-white/75 uppercase">
              {site.name} for Mac
            </p>
            <p className="mt-8 font-pixel text-[7.5rem] leading-[0.8] tracking-[-0.04em] sm:text-[10rem]">
              {site.price.label}
            </p>
            <p className="mt-6 font-mono text-xs tracking-wide text-white/75">
              One-time purchase · {site.price.currency}
            </p>
            <div className="mt-auto pt-12">
              <BuyButton tone="light" />
              <p className="mt-4 font-mono text-xs tracking-wide text-white/75">{site.requirements}</p>
            </div>
          </div>

          <ul className="flex flex-col justify-center gap-5 border-t border-white/20 p-8 sm:p-12 md:border-t-0 md:border-l">
            {included.map((item) => (
              <li key={item} className="flex items-center gap-4 text-lg">
                <PixelArt art={pixelIcons.check} className="size-[14px] shrink-0 text-white" />
                {item}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
