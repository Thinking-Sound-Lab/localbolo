import Link from "next/link";
import { DocPage, type DocSection } from "@/components/doc-page";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/terms",
  title: "Terms of service",
  description: `The terms for buying and using ${site.name}, including your license to use the app.`,
});

const email = <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>;

const sections: DocSection[] = [
  {
    id: "agreement",
    title: "Agreement",
    content: (
      <p>
        These terms are an agreement between you and {site.legalName} (“we”, “us”). By buying,
        downloading or using {site.name}, or using this website, you agree to them. If you don&apos;t
        agree, please don&apos;t use {site.name}.
      </p>
    ),
  },
  {
    id: "license",
    title: "Your license",
    content: (
      <>
        <p>
          When you buy {site.name}, we give you a personal, non-exclusive, non-transferable license
          to install and use it on the Macs you own or control, for personal or work use. The app
          is licensed to you, not sold.
        </p>
        <p>
          You activate {site.name} with the license key from your purchase email. A key works on a
          limited number of Macs at a time; to move it to a new Mac, deactivate it on the old one
          in {site.name}&apos;s Settings.
        </p>
        <p>
          Your license doesn&apos;t expire. It covers the version you bought and any updates we
          include with it. If a future major version is a paid upgrade, we&apos;ll say so before you
          download it, and the version you have keeps working.
        </p>
      </>
    ),
  },
  {
    id: "restrictions",
    title: "What you can't do",
    content: (
      <ul>
        <li>Share, resell, rent or give away your license or copies of the app.</li>
        <li>
          Reverse engineer, decompile or modify the app, except where the law allows it despite
          this restriction.
        </li>
        <li>Remove or work around any license checks or notices.</li>
        <li>Use the app to break the law or to record people without the consent the law requires.</li>
      </ul>
    ),
  },
  {
    id: "models",
    title: "Speech and language models",
    content: (
      <p>
        {site.name} downloads open models from Hugging Face, such as NVIDIA Parakeet, OpenAI
        Whisper and Qwen. Each model is provided by its authors under its own license, and your use
        of it is also subject to that license.
      </p>
    ),
  },
  {
    id: "accuracy",
    title: "Check your transcripts",
    content: (
      <p>
        Speech recognition and cleanup can make mistakes: a word misheard, a name misspelled, a
        correction applied the wrong way. Always review text before you send or rely on it,
        especially for anything medical, legal or financial.
      </p>
    ),
  },
  {
    id: "payment",
    title: "Payment and refunds",
    content: (
      <p>
        Prices are shown on this website and charged once. Dodo Payments sells {site.name} on our
        behalf as the merchant of record: it processes your payment, adds any taxes required where
        you live, and its buyer terms also apply to your purchase. If {site.name} isn&apos;t right
        for you, you can ask for a full refund within {site.refundDays} days. See the{" "}
        <Link href="/refunds">refund policy</Link>.
      </p>
    ),
  },
  {
    id: "warranty",
    title: "No warranty",
    content: (
      <p>
        We work hard to make {site.name} reliable, but it is provided “as is”, without warranties
        of any kind, to the extent the law allows. We don&apos;t promise that it will be free of
        errors or work without interruption on every Mac.
      </p>
    ),
  },
  {
    id: "liability",
    title: "Limitation of liability",
    content: (
      <p>
        To the extent the law allows, we aren&apos;t liable for indirect, incidental or
        consequential losses, or for lost data or profits, arising from your use of {site.name}.
        Our total liability to you is limited to the amount you paid for it. Nothing in these terms
        limits rights you have as a consumer that can&apos;t be limited by agreement.
      </p>
    ),
  },
  {
    id: "termination",
    title: "Ending the license",
    content: (
      <p>
        Your license ends if you break these terms or if you receive a refund. When it ends, you
        must stop using {site.name} and delete it.
      </p>
    ),
  },
  {
    id: "trademarks",
    title: "Other companies' names and logos",
    content: (
      <p>
        App names and logos shown on this site belong to their owners and appear only to show where{" "}
        {site.name} works. {site.name} isn&apos;t affiliated with or endorsed by them.
      </p>
    ),
  },
  {
    id: "changes",
    title: "Changes to these terms",
    content: (
      <p>
        We may update these terms. We&apos;ll post the new version on this page and change the date
        at the top. Changes don&apos;t take away rights you already have for a purchase you&apos;ve
        made.
      </p>
    ),
  },
  {
    id: "contact",
    title: "Contact",
    content: <p>Questions about these terms? Email {email}.</p>,
  },
];

export default function TermsPage() {
  return (
    <DocPage
      eyebrow="Terms of service"
      title="The fine print, in plain words."
      intro={`What you agree to when you buy and use ${site.name}.`}
      updated="September 28, 2026"
      sections={sections}
    />
  );
}
