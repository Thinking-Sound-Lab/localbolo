import { SectionHeading } from "@/components/sections/section-heading";
import { cx } from "@/lib/cx";

/** A piece of what was said. Dropped pieces are left out of the typed text. */
type Fragment = { text: string; isDropped?: boolean };

const examples: Fragment[][] = [
  [{ text: "Let's meet today at " }, { text: "9 p.m., sorry, ", isDropped: true }, { text: "10 p.m." }],
  [
    { text: "So, um, ", isDropped: true },
    { text: "I think we should" },
    { text: ", uh,", isDropped: true },
    { text: " ship it on Friday." },
  ],
  [{ text: "Send the deck to " }, { text: "Priya, no wait, to ", isDropped: true }, { text: "Sam." }],
];

export function Cleanup() {
  return (
    <section id="cleanup" className="scroll-mt-16 border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 sm:py-32 lg:grid-cols-[1fr_1.25fr]">
        <div>
          <SectionHeading eyebrow="Cleanup" title="Say it messy. Get it clean.">
            Turn on cleanup and a small language model on your Mac applies your self-corrections and
            drops the ums and uhs. If an edit would change what you meant, your words are kept as
            spoken.
          </SectionHeading>
          <p className="mt-8 font-mono text-xs tracking-wide text-ink-faint">
            Optional · Qwen 2.5 1.5B · 880 MB · On-device
          </p>
        </div>

        <ul className="border-b border-line">
          {examples.map((fragments) => {
            const typed = fragments
              .filter((fragment) => !fragment.isDropped)
              .map((fragment) => fragment.text)
              .join("");

            return (
              <li
                key={typed}
                className="grid gap-x-6 gap-y-2 border-t border-line py-7 sm:grid-cols-[6.5rem_1fr]"
              >
                <Label className="text-ink-faint">You said</Label>
                <p className="text-lg text-ink-soft">
                  {fragments.map((fragment) =>
                    fragment.isDropped ? (
                      <del
                        key={fragment.text}
                        className="text-ink-faint/80 decoration-blue decoration-[1.5px]"
                      >
                        {fragment.text}
                      </del>
                    ) : (
                      fragment.text
                    ),
                  )}
                </p>
                <Label className="mt-3 text-blue sm:mt-0">It typed</Label>
                <p className="text-xl font-medium tracking-[-0.02em] sm:text-2xl">{typed}</p>
              </li>
            );
          })}
        </ul>
      </div>
    </section>
  );
}

function Label({ children, className }: { children: string; className: string }) {
  return <p className={cx("pt-1.5 font-mono text-xs tracking-[0.14em] uppercase", className)}>{children}</p>;
}
