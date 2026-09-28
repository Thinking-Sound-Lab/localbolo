import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Eyebrow } from "@/components/sections/section-heading";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/privacy",
  title: "Privacy",
  description: `How ${site.name} handles your voice and data: recordings stay on your Mac, with no accounts, analytics, or tracking.`,
});

const sections = [
  {
    title: "Your voice never leaves your Mac",
    body: `${site.name} records audio only while you hold the fn key. The recording is kept in memory, transcribed by a speech model running on your Mac, and discarded as soon as the text is ready. It is never written to disk or sent anywhere.`,
  },
  {
    title: "No accounts, analytics, or tracking",
    body: `${site.name} has no sign-in, collects no analytics, and contains no third-party tracking code.`,
  },
  {
    title: "The only network request",
    body: "When you choose a speech model, or turn on transcript cleanup, the app downloads that model from Hugging Face. Nothing about you or your recordings is included in that request.",
  },
  {
    title: "Permissions",
    body: "Microphone access is used to record while you hold fn. Accessibility access is used to notice the fn key while other apps are in front and to paste the transcript at your cursor. The app reacts only to the fn key and does not record your typing.",
  },
  {
    title: "Your clipboard",
    body: "To paste into any app, the transcript is briefly placed on the clipboard. Whatever you had copied before is restored immediately afterwards, and the transcript is marked so clipboard managers can skip it.",
  },
];

export default function PrivacyPage() {
  return (
    <>
      <SiteHeader />
      <main id="main" className="mx-auto max-w-3xl px-6 py-20 sm:py-28">
        <Eyebrow>Privacy</Eyebrow>
        <h1 className="mt-5 text-5xl leading-[0.95] font-medium tracking-[-0.045em] sm:text-7xl">
          Private by <span className="font-pixel font-normal tracking-[-0.02em] text-blue">design.</span>
        </h1>
        <p className="mt-7 text-lg text-ink-soft">
          {site.name} is built so that there is nothing to collect. Here is exactly what the app
          does with your data.
        </p>

        <div className="mt-14 border-b border-line">
          {sections.map((section, index) => (
            <section key={section.title} className="grid gap-3 border-t border-line py-8 sm:grid-cols-[3rem_1fr]">
              <p className="pt-1 font-mono text-xs text-ink-faint">0{index + 1}</p>
              <div>
                <h2 className="text-xl font-medium tracking-[-0.02em]">{section.title}</h2>
                <p className="mt-2 leading-relaxed text-ink-soft">{section.body}</p>
              </div>
            </section>
          ))}
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
