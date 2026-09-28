import { Card } from "@/components/card";
import { SectionHeading } from "@/components/sections/section-heading";
import { cx } from "@/lib/cx";

/** Typical rates, in words per minute. */
const rates = [
  { label: "Typing", wordsPerMinute: 40, isHighlighted: false },
  { label: "Speaking", wordsPerMinute: 150, isHighlighted: true },
];

/** Each pixel in a bar stands for this many words per minute. */
const wordsPerPixel = 10;
const barLength = 16;

export function Speed() {
  return (
    <section id="speed" className="scroll-mt-16">
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-6 py-24 sm:py-32 lg:grid-cols-2">
        <SectionHeading eyebrow="Speed" title="Speak over three times faster than you type.">
          Most people type about 40 words a minute and speak about 150. With LocalBolo you write
          at the speed you talk, in every app, without sending a word to the cloud.
        </SectionHeading>

        <Card title="Words per minute" subtitle="Typical rates" index={1}>
          <dl className="mt-8 space-y-7">
            {rates.map((rate) => (
              <div key={rate.label}>
                <div className="flex items-baseline justify-between">
                  <dt className="font-mono text-[11px] tracking-[0.12em] text-ink-faint uppercase">
                    {rate.label}
                  </dt>
                  <dd className="text-4xl tracking-[-0.03em]">
                    {rate.wordsPerMinute}
                    <span className="ml-1 text-sm text-ink-faint">wpm</span>
                  </dd>
                </div>
                <div aria-hidden className="mt-3 grid grid-cols-16 gap-[3px]">
                  {Array.from({ length: barLength }, (_, index) => (
                    <span
                      key={index}
                      className={cx(
                        "aspect-square",
                        index < rate.wordsPerMinute / wordsPerPixel
                          ? rate.isHighlighted
                            ? "bg-blue"
                            : "bg-ink"
                          : "bg-mist",
                      )}
                    />
                  ))}
                </div>
              </div>
            ))}
          </dl>
        </Card>
      </div>
    </section>
  );
}
