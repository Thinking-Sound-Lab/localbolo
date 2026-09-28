import { SectionHeading } from "@/components/sections/section-heading";
import { cx } from "@/lib/cx";
import { speechModels } from "@/lib/models";

/** Each pixel in a model's size bar stands for this many megabytes. */
const megabytesPerPixel = 50;

export function Models() {
  return (
    <section id="models" className="scroll-mt-16">
      <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 sm:py-32 lg:grid-cols-[1fr_1.3fr]">
        <SectionHeading eyebrow="Models" title="Pick the model that fits.">
          Every model runs on the Neural Engine in Apple Silicon. Download one once, and switch any
          time in Settings.
        </SectionHeading>

        <div>
          <ul className="border-b border-line">
            {speechModels.map((model) => (
              <li key={model.name} className="grid gap-4 border-t border-line py-6 sm:grid-cols-[1fr_auto]">
                <div>
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-xl font-medium tracking-[-0.02em]">{model.name}</h3>
                    {model.recommended ? (
                      <span className="bg-blue px-2 py-1 font-mono text-[11px] leading-none tracking-[0.12em] text-white uppercase">
                        Recommended
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1.5 text-ink-soft">{model.summary}</p>
                  <p className="mt-1 font-mono text-xs tracking-wide text-ink-faint">{model.engine}</p>
                </div>
                <SizeBar megabytes={model.megabytes} isHighlighted={model.recommended} />
              </li>
            ))}
          </ul>
          <p className="mt-5 text-sm text-ink-faint">
            Optional transcript cleanup uses Qwen 2.5 1.5B (880 MB), a small language model that
            also runs on your Mac. Models are downloaded from Hugging Face the first time you pick
            them. After that, everything works offline.
          </p>
        </div>
      </div>
    </section>
  );
}

/** A model's download size as a row of pixels, one per 50 MB. */
function SizeBar({ megabytes, isHighlighted = false }: { megabytes: number; isHighlighted?: boolean }) {
  const pixels = Math.round(megabytes / megabytesPerPixel);

  return (
    <div className="flex flex-col gap-2 sm:items-end">
      <span className="font-mono text-sm text-ink">{megabytes} MB</span>
      <div aria-hidden className="flex gap-[3px]">
        {Array.from({ length: pixels }, (_, index) => (
          <span key={index} className={cx("size-2", isHighlighted ? "bg-blue" : "bg-ink")} />
        ))}
      </div>
    </div>
  );
}
