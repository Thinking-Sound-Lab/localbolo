import { Card } from "@/components/card";
import { SectionHeading } from "@/components/sections/section-heading";
import { cx } from "@/lib/cx";
import { speechModels } from "@/lib/models";

/** Each pixel in a model's size bar stands for this many megabytes. */
const megabytesPerPixel = 50;
/** Long enough for the largest model. */
const barLength = 14;

export function Models() {
  return (
    <section id="models" className="scroll-mt-16">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="Models" title="Pick the model that fits.">
          Every model runs on the Neural Engine in Apple Silicon. Download one once, and switch any
          time in Settings.
        </SectionHeading>

        <ul className="mt-14 grid gap-4 sm:grid-cols-2">
          {speechModels.map((model, index) => (
            <li key={model.name} className="flex">
              <Card
                title={
                  <span className="flex flex-wrap items-center gap-3">
                    {model.name}
                    {model.recommended ? (
                      <span className="bg-blue px-2 py-1 font-mono text-[10px] leading-none tracking-[0.12em] text-white uppercase">
                        Recommended
                      </span>
                    ) : null}
                  </span>
                }
                subtitle={model.engine}
                index={index + 1}
                className="flex-1"
              >
                <p className="mt-4 text-ink-soft">{model.summary}</p>
                <p className="mt-8 text-4xl tracking-[-0.03em]">
                  {model.megabytes}
                  <span className="ml-1 text-sm text-ink-faint">MB</span>
                </p>
                <div aria-hidden className="mt-3 grid grid-cols-14 gap-[3px]">
                  {Array.from({ length: barLength }, (_, pixel) => (
                    <span
                      key={pixel}
                      className={cx(
                        "aspect-square",
                        pixel < Math.round(model.megabytes / megabytesPerPixel)
                          ? model.recommended
                            ? "bg-blue"
                            : "bg-ink"
                          : "bg-mist",
                      )}
                    />
                  ))}
                </div>
              </Card>
            </li>
          ))}
        </ul>
        <p className="mt-6 max-w-2xl text-sm text-ink-faint">
          Optional transcript cleanup uses Qwen 2.5 1.5B (880 MB), a small language model that also
          runs on your Mac. Models are downloaded from Hugging Face the first time you pick them.
          After that, everything works offline.
        </p>
      </div>
    </section>
  );
}
