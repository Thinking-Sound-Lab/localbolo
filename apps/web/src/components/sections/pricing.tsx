import Link from "next/link";
import { BuyButton } from "@/components/buy-button";
import { PixelArt } from "@/components/pixel-art";
import { SectionHeading } from "@/components/sections/section-heading";
import { pixelIcons } from "@/lib/pixel-icons";
import { site } from "@/lib/site";
import { licensePlans } from "@/lib/pricing";

const included = [
  "Unlimited dictation in every app",
  "Every speech model: Parakeet and Whisper",
  "On-device transcript cleanup",
  "Offline dictation between license checks",
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

        <div className="mt-14 bg-blue text-white pixel-grid [--pixel-color:rgb(255_255_255/0.2)]">
          <div className="grid divide-y divide-white/25 md:grid-cols-3 md:divide-x md:divide-y-0">
            {licensePlans.map((plan) => (
              <div key={plan.id} className="flex flex-col p-8 sm:p-10 md:px-8">
                <h3 className="text-2xl font-medium tracking-tight">{plan.name}</h3>
                <p className="mt-3 text-white/85">
                  One license key for {plan.name}
                </p>
                <p className="mt-8 text-lg text-white/80">
                  <span className="sr-only">Original price </span><del>{plan.originalLabel}</del>
                </p>
                <p className="mt-2 font-pixel text-7xl leading-none tracking-[-0.04em] sm:text-8xl md:text-7xl lg:text-8xl xl:text-[7.5rem]">
                  <span className="sr-only">Current price </span>
                  {plan.label}
                </p>
                <p className="mt-4 text-sm text-white/85">One-time purchase in {site.price.currency}</p>
                <div className="mt-9"><BuyButton plan={plan} tone="white" /></div>
              </div>
            ))}
          </div>
          <div className="border-t border-white/25 p-8 sm:p-10">
            <p className="text-xl font-medium">Every license includes</p>
            <ul className="mt-6 grid gap-5 md:grid-cols-2">
              {included.map((item) => (
                <li key={item} className="flex items-center gap-4 text-lg">
                  <PixelArt art={pixelIcons.check} className="size-[14px] shrink-0 text-white" />
                  {item}
                </li>
              ))}
            </ul>
            <p className="mt-8 text-sm text-white/85">
              One key per plan, with 1, 2, or 5 Mac activations. Deactivate a Mac in Settings to move an activation.
              Secure checkout by Dodo Payments. {site.requirements}.
            </p>
          </div>
        </div>

        <p className="mt-5 text-sm text-ink-faint">
          Not for you? Ask within {site.refundDays} days for a full refund.{" "}
          <Link href="/refunds" className="text-ink underline underline-offset-4 hover:text-blue">
            Refund policy
          </Link>
        </p>
      </div>
    </section>
  );
}
