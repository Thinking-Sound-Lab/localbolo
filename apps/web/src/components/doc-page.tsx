import type { ReactNode } from "react";
import { CardIndex } from "@/components/card";
import { Eyebrow } from "@/components/sections/section-heading";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

export type DocSection = { id: string; title: string; content: ReactNode };

/**
 * A long-form page such as a policy or the help page: numbered sections with
 * an "On this page" list beside them on wide screens.
 */
export function DocPage({
  eyebrow,
  title,
  intro,
  updated,
  sections,
}: {
  eyebrow: string;
  title: ReactNode;
  intro?: ReactNode;
  /** When the page's content last changed, for policies. */
  updated?: string;
  sections: DocSection[];
}) {
  return (
    <>
      <SiteHeader />
      <main
        id="main"
        className="mx-auto grid max-w-6xl gap-12 px-6 py-16 sm:py-24 lg:grid-cols-[13rem_1fr] lg:gap-16"
      >
        <aside className="hidden lg:block">
          <nav aria-label="On this page" className="sticky top-28">
            <p className="font-mono text-[11px] tracking-[0.12em] text-ink-faint uppercase">
              On this page
            </p>
            <ol className="mt-4 space-y-1 border-l border-line">
              {sections.map((section) => (
                <li key={section.id}>
                  <a
                    href={`#${section.id}`}
                    className="-ml-px block border-l border-transparent py-1 pl-4 text-sm text-ink-soft transition-colors hover:border-blue hover:text-ink"
                  >
                    {section.title}
                  </a>
                </li>
              ))}
            </ol>
          </nav>
        </aside>

        <article className="max-w-3xl">
          <Eyebrow>{eyebrow}</Eyebrow>
          <h1 className="mt-5 text-5xl leading-[0.95] font-medium tracking-[-0.045em] text-balance sm:text-6xl">
            {title}
          </h1>
          {intro ? <p className="mt-7 text-lg text-pretty text-ink-soft">{intro}</p> : null}
          {updated ? (
            <p className="mt-6 font-mono text-xs tracking-wide text-ink-faint">Last updated {updated}</p>
          ) : null}

          <div className="mt-12 border-b border-line">
            {sections.map((section, index) => (
              <section
                key={section.id}
                id={section.id}
                className="grid scroll-mt-24 gap-3 border-t border-line py-8 sm:grid-cols-[3.5rem_1fr]"
              >
                <CardIndex index={index + 1} className="pt-1.5" />
                <div>
                  <h2 className="text-xl font-medium tracking-[-0.02em]">{section.title}</h2>
                  <div className="mt-3 space-y-3 leading-relaxed text-ink-soft [&_a]:text-ink [&_a]:underline [&_code]:bg-mist [&_code]:px-1 [&_code]:font-mono [&_code]:text-[0.85em] [&_a]:underline-offset-4 [&_a:hover]:text-blue [&_li]:pl-1 [&_strong]:font-medium [&_strong]:text-ink [&_ul]:list-[square] [&_ul]:space-y-2 [&_ul]:pl-5">
                    {section.content}
                  </div>
                </div>
              </section>
            ))}
          </div>
        </article>
      </main>
      <SiteFooter />
    </>
  );
}
