import Link from "next/link";
import { DocPage, type DocSection } from "@/components/doc-page";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/support",
  title: "Help and contact",
  description: `Get help with ${site.name}: system requirements, fixes for common problems, and how to reach us.`,
});

const email = <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>;

const sections: DocSection[] = [
  {
    id: "contact",
    title: "Contact us",
    content: (
      <>
        <p>
          Email {email}. A person who works on {site.name} reads every message.
        </p>
        <p>
          If something isn&apos;t working, tell us your Mac model, your macOS version, and the
          version of {site.name} (select it in Applications and choose File › Get Info). Please
          don&apos;t attach recordings or transcripts unless you want us to see them.
        </p>
      </>
    ),
  },
  {
    id: "requirements",
    title: "System requirements",
    content: (
      <ul>
        <li>
          <strong>A Mac with Apple Silicon</strong> (M1 or newer). The speech models run on the
          Neural Engine, which Intel Macs don&apos;t have.
        </li>
        <li>
          <strong>macOS 15 Sequoia</strong> or later.
        </li>
        <li>
          <strong>Disk space</strong> for the model you choose: 470 MB for Parakeet v2, the
          default, plus 880 MB if you turn on transcript cleanup.
        </li>
        <li>
          <strong>8 GB of memory</strong> is enough, including with cleanup turned on.
        </li>
        <li>
          <strong>An internet connection</strong> only to download models. After that, dictation
          works offline.
        </li>
      </ul>
    ),
  },
  {
    id: "not-pasting",
    title: "The text isn't pasted",
    content: (
      <>
        <p>
          {site.name} needs Accessibility access to paste. Click the menu bar icon, choose Setup
          Guide, and click Open Settings next to Accessibility, then turn {site.name} on.
        </p>
        <p>
          If it already looks on, for example after an update, click Open Settings in the Setup
          Guide anyway: it clears the old entry so you can turn it on again. Until then, each
          transcript is copied to the clipboard so you can paste it yourself.
        </p>
      </>
    ),
  },
  {
    id: "emoji-picker",
    title: "Pressing fn opens the emoji picker",
    content: (
      <p>
        Open System Settings › Keyboard and set “Press 🌐 key to” to “Do Nothing”. The Setup Guide
        in {site.name} links straight there.
      </p>
    ),
  },
  {
    id: "nothing-happens",
    title: "Nothing happens when I hold fn",
    content: (
      <ul>
        <li>Hold fn for at least a quarter of a second. Quick taps are ignored on purpose.</li>
        <li>
          Check that {site.name} has Microphone access in System Settings › Privacy & Security ›
          Microphone.
        </li>
        <li>
          Make sure a speech model has finished downloading. Click the menu bar icon to see its
          progress.
        </li>
      </ul>
    ),
  },
  {
    id: "first-dictation",
    title: "The first dictation is slow",
    content: (
      <p>
        The first time a model loads, macOS optimizes it for your Mac&apos;s Neural Engine, which
        can take up to a minute. It happens once per model. After that, dictation starts right away.
      </p>
    ),
  },
  {
    id: "more",
    title: "More answers",
    content: (
      <p>
        The <Link href="/#faq">FAQ</Link> covers pricing, languages and privacy. The{" "}
        <Link href="/privacy">privacy policy</Link> explains exactly what the app does with your
        data, and the <Link href="/changelog">changelog</Link> lists what&apos;s new in each
        version.
      </p>
    ),
  },
];

export default function SupportPage() {
  return (
    <DocPage
      eyebrow="Support"
      title="How can we help?"
      intro="Answers to the most common questions, and how to reach a person when you need one."
      sections={sections}
    />
  );
}
