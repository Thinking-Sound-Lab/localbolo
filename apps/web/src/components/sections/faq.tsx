import Link from "next/link";
import { PixelArt } from "@/components/pixel-art";
import { SectionHeading } from "@/components/sections/section-heading";
import { faq } from "@/lib/faq";
import { pixelIcons } from "@/lib/pixel-icons";
import { site } from "@/lib/site";

export function Faq() {
  return (
    <section id="faq" className="scroll-mt-16 border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 sm:py-32 lg:grid-cols-[1fr_1.3fr]">
        <div>
          <SectionHeading eyebrow="FAQ" title="Questions, answered." />
          <p className="mt-6 text-ink-soft">
            Something else?{" "}
            <Link href="/support" className="text-ink underline underline-offset-4 hover:text-blue">
              Visit support
            </Link>{" "}
            or email{" "}
            <a
              href={`mailto:${site.supportEmail}`}
              className="text-ink underline underline-offset-4 hover:text-blue"
            >
              {site.supportEmail}
            </a>
            .
          </p>
        </div>

        <div className="border-b border-line">
          {faq.map((item) => (
            <details key={item.question} className="group border-t border-line py-6">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-lg font-medium tracking-[-0.02em] [&::-webkit-details-marker]:hidden">
                {item.question}
                <PixelArt
                  art={pixelIcons.plus}
                  className="size-[15px] shrink-0 text-ink transition-transform duration-200 group-open:rotate-45 group-open:text-blue"
                />
              </summary>
              <p className="mt-3 max-w-2xl pr-10 text-ink-soft">{item.answer}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
