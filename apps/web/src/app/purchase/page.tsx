import type { Metadata } from "next";
import Link from "next/link";
import { BuyButton, SecondaryLink } from "@/components/buy-button";
import { Eyebrow } from "@/components/sections/section-heading";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Your purchase",
  robots: { index: false, follow: false },
  // The URL can carry the buyer's license key, so never send it to other sites.
  referrer: "no-referrer",
};

type Outcome = "succeeded" | "pending" | "failed" | "unavailable";

/**
 * Dodo's payment status, as added to the return URL, grouped by what the
 * buyer needs to hear. /buy sends "unavailable" when checkout can't start.
 */
function outcomeOf(status: string | undefined): Outcome {
  if (status === "succeeded") return "succeeded";
  if (status === "failed" || status === "cancelled") return "failed";
  if (status === "processing" || status?.startsWith("requires_")) return "pending";
  return "unavailable";
}

const email = (
  <a href={`mailto:${site.supportEmail}`} className="text-ink underline underline-offset-4 hover:text-blue">
    {site.supportEmail}
  </a>
);

/**
 * Where Dodo Payments sends buyers after checkout. The page only reports the
 * outcome: Dodo emails the receipt, the download and any license key.
 */
export default async function PurchasePage({ searchParams }: PageProps<"/purchase">) {
  const params = await searchParams;
  const status = typeof params.status === "string" ? params.status : undefined;
  const buyerEmail = typeof params.email === "string" ? params.email : undefined;
  const licenseKey = typeof params.license_key === "string" ? params.license_key : undefined;
  const outcome = outcomeOf(status);

  return (
    <>
      <SiteHeader />
      <main id="main" className="pixel-grid">
        <div className="mx-auto max-w-2xl px-6 py-20 sm:py-28">
          {outcome === "succeeded" ? (
            <>
              <Eyebrow>Purchase complete</Eyebrow>
              <h1 className="mt-5 text-5xl leading-[0.95] font-medium tracking-[-0.045em] sm:text-6xl">
                Thank you. {site.name} is <span className="font-pixel font-normal text-blue">yours.</span>
              </h1>
              <p className="mt-6 text-lg text-ink-soft">
                We&apos;ve emailed your receipt and download link
                {buyerEmail ? (
                  <>
                    {" "}
                    to <strong className="font-medium text-ink">{buyerEmail}</strong>
                  </>
                ) : null}
                . It comes from Dodo Payments, who handle checkout for us.
              </p>

              {licenseKey ? (
                <div className="mt-8 border border-line bg-white p-6">
                  <p className="font-mono text-[11px] tracking-[0.12em] text-ink-faint uppercase">
                    Your license key
                  </p>
                  <p className="mt-2 font-mono text-lg break-all select-all">{licenseKey}</p>
                  <p className="mt-2 text-sm text-ink-faint">It&apos;s in your email too.</p>
                </div>
              ) : null}

              <ol className="mt-8 border border-line bg-white">
                {[
                  "Open the email from Dodo Payments and download LocalBolo.",
                  "Drag LocalBolo to your Applications folder and open it.",
                  "Follow the setup guide, then hold fn and start talking.",
                ].map((step, index) => (
                  <li key={step} className="flex gap-4 border-line p-5 not-first:border-t">
                    <span className="pt-0.5 font-mono text-[11px] text-ink-faint">
                      {String(index + 1).padStart(3, "0")}
                    </span>
                    {step}
                  </li>
                ))}
              </ol>
              <p className="mt-6 text-ink-soft">
                No email after a few minutes? Check your spam folder, or write to {email}.
              </p>
            </>
          ) : outcome === "pending" ? (
            <>
              <Eyebrow>Payment processing</Eyebrow>
              <h1 className="mt-5 text-5xl leading-[0.95] font-medium tracking-[-0.045em] sm:text-6xl">
                Almost there.
              </h1>
              <p className="mt-6 text-lg text-ink-soft">
                Your payment is still being processed. As soon as it goes through, we&apos;ll email
                your receipt and download link. Questions? Write to {email}.
              </p>
            </>
          ) : outcome === "failed" ? (
            <>
              <Eyebrow>Payment not completed</Eyebrow>
              <h1 className="mt-5 text-5xl leading-[0.95] font-medium tracking-[-0.045em] sm:text-6xl">
                Your payment didn&apos;t go through.
              </h1>
              <p className="mt-6 text-lg text-ink-soft">
                You haven&apos;t been charged. You can try again, with the same card or a different
                one.
              </p>
              <div className="mt-10 flex flex-col gap-3 sm:flex-row">
                <BuyButton />
                <SecondaryLink href="/support">Get help</SecondaryLink>
              </div>
            </>
          ) : (
            <>
              <Eyebrow>Checkout</Eyebrow>
              <h1 className="mt-5 text-5xl leading-[0.95] font-medium tracking-[-0.045em] sm:text-6xl">
                Checkout isn&apos;t available right now.
              </h1>
              <p className="mt-6 text-lg text-ink-soft">
                Please try again in a minute. If it keeps happening, write to {email} and
                we&apos;ll sort it out.
              </p>
              <div className="mt-10 flex flex-col gap-3 sm:flex-row">
                <BuyButton />
                <SecondaryLink href="/">Back to home</SecondaryLink>
              </div>
            </>
          )}

          <p className="mt-16 text-sm text-ink-faint">
            Payments are processed by Dodo Payments, the merchant of record for {site.name}. See
            our <Link href="/refunds" className="underline underline-offset-4 hover:text-ink">refund policy</Link>.
          </p>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
