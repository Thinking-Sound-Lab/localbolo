import { DocPage, type DocSection } from "@/components/doc-page";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/changelog",
  title: "Changelog",
  description: `What's new in each version of ${site.name}.`,
});

/** Releases, newest first. */
const releases: { version: string; date: string; changes: string[] }[] = [
  {
    version: "0.1",
    date: "September 28, 2026",
    changes: [
      "Hold fn anywhere to dictate, and let go to paste the text at your cursor.",
      "The pill shows the icon of the app your words will land in, with a live waveform.",
      "NVIDIA Parakeet v2 as the default speech model, plus Whisper Base, Small and Large v3 Turbo.",
      "Optional transcript cleanup with Qwen 2.5 1.5B, running on your Mac, which applies your self-corrections and removes filler words.",
      "Your clipboard is restored after every paste.",
      "Copy Last Transcript from the menu bar.",
      "A setup guide for the microphone, Accessibility and the fn key.",
      "Launch at login.",
    ],
  },
];

const sections: DocSection[] = releases.map((release) => ({
  id: `v${release.version.replaceAll(".", "-")}`,
  title: `${site.name} ${release.version} · ${release.date}`,
  content: (
    <ul>
      {release.changes.map((change) => (
        <li key={change}>{change}</li>
      ))}
    </ul>
  ),
}));

export default function ChangelogPage() {
  return (
    <DocPage
      eyebrow="Changelog"
      title="What's new."
      intro={`Every version of ${site.name}, newest first.`}
      sections={sections}
    />
  );
}
