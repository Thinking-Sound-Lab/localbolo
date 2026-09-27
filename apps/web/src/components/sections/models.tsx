import { SectionHeading } from "@/components/sections/section-heading";
import { speechModels } from "@/lib/models";

export function Models() {
  return (
    <section id="models" className="scroll-mt-20 border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 sm:py-32 lg:grid-cols-[1fr_1.3fr]">
        <SectionHeading eyebrow="Models" title="Pick the model that fits.">
          Every model runs on the Neural Engine in Apple Silicon. Download one once, and switch
          any time in Settings.
        </SectionHeading>

        <div>
          <ul className="divide-y divide-line overflow-hidden rounded-3xl border border-line bg-white/70">
            {speechModels.map((model) => (
              <li key={model.name} className="flex items-start justify-between gap-6 p-5 sm:p-6">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="text-lg font-semibold tracking-tight">{model.name}</h3>
                    {model.recommended ? (
                      <span className="rounded-full bg-ember px-2 py-0.5 text-xs font-medium text-white">
                        Recommended
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1 text-ink-soft">{model.summary}</p>
                  <p className="mt-1 text-sm text-ink-faint">{model.engine}</p>
                </div>
                <span className="shrink-0 rounded-full bg-paper-deep px-3 py-1 font-mono text-sm text-ink-soft">
                  {model.size}
                </span>
              </li>
            ))}
          </ul>
          <p className="mt-4 text-sm text-ink-faint">
            Optional transcript cleanup uses Qwen 2.5 1.5B (880 MB), a small language model that
            also runs on your Mac. Models are downloaded from Hugging Face the first time you
            pick them. After that, everything works offline.
          </p>
        </div>
      </div>
    </section>
  );
}
