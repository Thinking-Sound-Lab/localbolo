import type { Metadata } from "next";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy",
  description: `How ${site.name} handles your voice and data.`,
};

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
      <main className="mx-auto max-w-2xl px-6 py-20 sm:py-28">
        <p className="text-sm font-medium tracking-wide text-ember uppercase">Privacy</p>
        <h1 className="mt-3 font-display text-6xl leading-none tracking-tight">Private by design.</h1>
        <p className="mt-6 text-lg text-ink-soft">
          {site.name} is built so that there is nothing to collect. Here is exactly what the app
          does with your data.
        </p>

        <div className="mt-14 space-y-10">
          {sections.map((section) => (
            <section key={section.title}>
              <h2 className="text-xl font-semibold tracking-tight">{section.title}</h2>
              <p className="mt-2 leading-relaxed text-ink-soft">{section.body}</p>
            </section>
          ))}
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
