import { DocPage, type DocSection } from "@/components/doc-page";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/privacy",
  title: "Privacy policy",
  description: `How ${site.name} handles your voice and data: recordings stay on your Mac, with no accounts, analytics, or tracking.`,
});

const email = <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>;

const sections: DocSection[] = [
  {
    id: "summary",
    title: "The short version",
    content: (
      <>
        <p>
          {site.name} turns your speech into text on your Mac. Your recordings and transcripts are
          never sent to us or anyone else. The app has no account, no analytics and no tracking.
        </p>
        <p>
          We only handle personal information when you buy {site.name}, activate it, or contact us,
          and only to deliver your purchase, check your license and help you.
        </p>
      </>
    ),
  },
  {
    id: "who-we-are",
    title: "Who we are",
    content: (
      <p>
        {site.name} is made by {site.legalName} (“we”, “us”). We are responsible for the personal
        information described in this policy. You can reach us at {email}.
      </p>
    ),
  },
  {
    id: "voice",
    title: "Your voice and transcripts",
    content: (
      <>
        <p>
          {site.name} records audio only while you hold the fn key. The recording is kept in memory,
          transcribed by a speech model running on your Mac, and discarded as soon as the text is
          ready. It is never written to disk and never sent anywhere.
        </p>
        <p>
          The transcript is pasted into the app you are using. {site.name} does not keep a history
          of what you dictate. If you turn on transcript cleanup, the language model that tidies
          the text also runs on your Mac.
        </p>
      </>
    ),
  },
  {
    id: "permissions",
    title: "Permissions on your Mac",
    content: (
      <ul>
        <li>
          <strong>Microphone</strong> is used to record while you hold fn, and at no other time.
        </li>
        <li>
          <strong>Accessibility</strong> is used to notice the fn key while another app is in
          front, and to paste the transcript at your cursor. {site.name} reacts only to the fn key
          and does not record your typing.
        </li>
        <li>
          <strong>Clipboard.</strong> To paste into any app, the transcript is briefly placed on
          the clipboard. By default, whatever you had copied is restored straight afterwards, and
          the transcript is marked so clipboard managers can skip it. If you turn off “Restore
          clipboard after pasting” in Settings, or haven&apos;t allowed Accessibility yet, the
          transcript stays on the clipboard like anything else you copy.
        </li>
      </ul>
    ),
  },
  {
    id: "on-your-mac",
    title: "What stays on your Mac",
    content: (
      <p>
        Your settings, such as the model you chose, and your license key are stored in your
        Mac&apos;s preferences, and downloaded models in{" "}
        <code>~/Library/Application Support/LocalBolo</code>. Deleting the app and that folder
        removes them.
      </p>
    ),
  },
  {
    id: "network",
    title: "Network requests",
    content: (
      <>
        <p>
          The app connects to the internet for three things, and never sends your recordings or
          transcripts:
        </p>
        <ul>
          <li>
            <strong>Models.</strong> It downloads the speech model you choose, and the cleanup model
            if you turn cleanup on, from Hugging Face, which receives the technical details of the
            request, such as your IP address, under its own privacy policy.
          </li>
          <li>
            <strong>Your license.</strong> When you enter your license key, the app activates it with
            Dodo Payments. It sends the key, your Mac&apos;s name, and an anonymous ID made from a
            one-way hash of your Mac&apos;s hardware ID, so a license stays tied to the Macs you
            activate. The hardware ID itself never leaves your Mac. Every two weeks, when
            you&apos;re online, the app checks with Dodo that the key is still valid. If it
            can&apos;t check for a month, it asks you to connect once before dictating again.
          </li>
          <li>
            <strong>Updates.</strong> Once a day, the app downloads a small list of versions from
            this website to see whether there&apos;s a new one, and downloads it if you choose to
            update. The request includes standard details such as your IP address and the app&apos;s
            version, and nothing else about your Mac. You can turn automatic checks off in Settings.
          </li>
        </ul>
      </>
    ),
  },
  {
    id: "website",
    title: "This website",
    content: (
      <p>
        This website sets no cookies and has no analytics or advertising trackers. Fonts are served
        from this site rather than a third party. Vercel, which hosts the site, may keep standard
        server logs, such as IP addresses and browser types, to deliver the site and protect it
        from abuse.
      </p>
    ),
  },
  {
    id: "purchases",
    title: "Purchases",
    content: (
      <>
        <p>
          {site.name} is sold through Dodo Payments, which acts as the merchant of record: it runs
          checkout, processes your payment, charges any sales tax and sends your receipt and
          download. It collects your payment details under{" "}
          <a href="https://dodopayments.com/privacy-policy">its own privacy policy</a>. We never see
          your full card number.
        </p>
        <p>
          We receive your name, email address, country and order details. We use them to deliver
          your purchase, process refunds, answer questions about your order, and keep the records
          that tax and accounting law require.
        </p>
        <p>
          We keep a record of each purchase: your name, email address and country, what you paid,
          whether it was refunded, and an ID for your license key (not the key itself). It&apos;s
          stored with Supabase, our database provider, and only we can see it.
        </p>
      </>
    ),
  },
  {
    id: "support",
    title: "When you contact us",
    content: (
      <p>
        If you email us, we use your message and address to reply and to fix problems you report.
        Please don&apos;t send recordings or transcripts unless you want us to see them.
      </p>
    ),
  },
  {
    id: "sharing",
    title: "Sharing and retention",
    content: (
      <>
        <p>
          We don&apos;t sell or rent personal information, and we don&apos;t share it for
          advertising. We share it only with the service providers above, to run the service, or
          when the law requires it.
        </p>
        <p>
          We keep order records for as long as tax and accounting law requires, and support emails
          for as long as we need them to help you.
        </p>
      </>
    ),
  },
  {
    id: "your-rights",
    title: "Your rights",
    content: (
      <p>
        You can ask us for a copy of the personal information we hold about you, or ask us to
        correct or delete it, by emailing {email}. Depending on where you live, you may also have
        the right to object to how we use it or to complain to your data protection authority.
      </p>
    ),
  },
  {
    id: "children",
    title: "Children",
    content: (
      <p>
        {site.name} is not directed at children under 13, and we don&apos;t knowingly collect
        their personal information.
      </p>
    ),
  },
  {
    id: "changes",
    title: "Changes to this policy",
    content: (
      <p>
        If we change this policy, we&apos;ll update it on this page and change the date at the
        top. If a change is significant, we&apos;ll say so clearly here before it takes effect.
      </p>
    ),
  },
];

export default function PrivacyPage() {
  return (
    <DocPage
      eyebrow="Privacy policy"
      title={
        <>
          Private by <span className="font-pixel font-normal tracking-[-0.02em] text-blue">design.</span>
        </>
      }
      intro={`${site.name} is built so that there is nothing to collect. Here is exactly what the app and this website do with your data.`}
      updated="September 29, 2026"
      sections={sections}
    />
  );
}
