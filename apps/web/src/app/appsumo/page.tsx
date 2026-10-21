import type { Metadata } from "next";
import { cookies } from "next/headers";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { appSumoCookies, openAppSumoCookie, uuidPattern, type AppSumoProfile } from "@/lib/appsumo";
import { appSumoProfile } from "@/lib/appsumo-store";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  // The callback already removes OAuth codes. same-origin keeps native form
  // POSTs' Origin header while withholding referrers from external sites.
  title: "Your AppSumo license", robots: { index: false, follow: false }, referrer: "same-origin",
};
export const dynamic = "force-dynamic";
const appSumoProducts = "https://appsumo.com/account/products/";
const button = "inline-flex min-h-12 items-center justify-center bg-ink px-6 font-medium text-white hover:bg-blue focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-blue";
const messages: Record<string, string> = {
  expired: "That activation link expired. Open LocalBolo in AppSumo My Products and choose Activate again.",
  inactive: "This AppSumo license is no longer active. Check your purchase in AppSumo My Products.",
  pending: "Your purchase is still syncing. Wait a minute, then choose Activate again in AppSumo My Products.",
  limited: "Too many attempts. Wait a minute, then choose Activate again in AppSumo My Products.",
  unavailable: "We couldn’t connect to your purchase. Try Activate again in AppSumo My Products in a minute.",
};

export default async function AppSumoPage({ searchParams }: PageProps<"/appsumo">) {
  const params = await searchParams;
  const jar = await cookies();
  const pending = openAppSumoCookie("pending", jar.get(appSumoCookies.pending)?.value);
  const session = openAppSumoCookie("session", jar.get(appSumoCookies.session)?.value);
  const confirming = params.confirm === "1" && typeof pending?.nonce === "string";
  let profile: AppSumoProfile | null = null;
  let unavailable = false;
  if (!confirming && typeof session?.licenseId === "string" && uuidPattern.test(session.licenseId)) {
    try { profile = await appSumoProfile(session.licenseId); } catch { unavailable = true; }
  }
  const error = typeof params.error === "string" ? messages[params.error] : undefined;

  return (
    <>
      <SiteHeader />
      <main id="main" className="mx-auto max-w-3xl px-6 py-20 sm:py-28">
        <p className="text-sm text-ink-faint">AppSumo purchase</p>
        <h1 className="mt-4 text-4xl leading-tight font-medium tracking-[-0.045em] sm:text-5xl">
          {confirming ? "Make LocalBolo yours." : profile?.status === "active" ? "Your LocalBolo license." : "Activate your LocalBolo license."}
        </h1>
        {(error || unavailable) && <p role="alert" className="mt-6 border-l-2 border-blue bg-blue-pale p-4 text-ink-soft">{error ?? messages.unavailable}</p>}

        {confirming ? (
          <>
            <p className="mt-6 max-w-xl text-lg text-ink-soft">Continue with the AppSumo purchase you just opened to see your license key and manage its Macs.</p>
            <form method="post" action="/appsumo/claim" className="mt-8">
              <input type="hidden" name="csrf" value={pending!.nonce as string} />
              <button className={button}>Continue with this purchase</button>
            </form>
            <p className="mt-5 text-sm text-ink-faint">Using a different purchase? Open it from <a href={appSumoProducts} rel="noreferrer" className="underline underline-offset-4">AppSumo My Products</a> first.</p>
          </>
        ) : profile?.status === "active" && profile.product_key ? (
          <>
            <p className="mt-6 text-lg text-ink-soft">One key for {profile.macs === 1 ? "1 Mac" : `up to ${profile.macs} Macs`}. Use the same key on each Mac in your plan.</p>
            <div className="mt-8 border border-line bg-mist p-5 sm:p-7">
              <label htmlFor="license-key" className="block text-sm font-medium">Your license key</label>
              <textarea id="license-key" readOnly value={profile.product_key} rows={3} spellCheck={false} autoComplete="off" className="mt-3 w-full resize-none border border-line bg-white p-3 font-mono text-sm break-all focus:outline-2 focus:outline-blue" />
              <p className="mt-3 text-sm text-ink-faint">Keep this key private. Select it above to copy it.</p>
            </div>
            <ol className="mt-8 list-decimal space-y-3 pl-5 text-ink-soft">
              <li><a href={site.downloadUrl} className="text-ink underline underline-offset-4 hover:text-blue">Download LocalBolo for Mac</a> and move it to Applications.</li>
              <li>Open LocalBolo and paste your key when asked for a license.</li>
              <li>Complete setup, then hold fn and start talking.</li>
            </ol>
            <p className="mt-4 text-sm text-ink-faint">Internet is needed for activation and occasional verification. Dictation works offline for up to 30 days between checks.</p>
            <section aria-labelledby="macs-heading" className="mt-14 border-t border-line pt-8">
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <h2 id="macs-heading" className="text-2xl font-medium tracking-tight">Your Macs</h2>
                <p className="text-sm text-ink-faint">{profile.devices.length} of {profile.macs} activated</p>
              </div>
              <p className="mt-3 text-ink-soft">Remove a Mac here to free a slot, including one you no longer have. It will ask for activation after its next license check.</p>
              {profile.devices.length ? (
                <ul className="mt-5 divide-y divide-line border-y border-line">
                  {profile.devices.map((device) => (
                    <li key={device.id} className="flex flex-wrap items-center justify-between gap-4 py-5">
                      <span className="min-w-0 break-words font-medium">{device.name}</span>
                      <form method="post" action="/appsumo/devices">
                        <input type="hidden" name="csrf" value={session!.nonce as string} />
                        <input type="hidden" name="instance" value={device.id} />
                        <button aria-label={`Remove ${device.name}`} className="min-h-11 px-3 text-sm underline underline-offset-4 hover:text-blue focus-visible:outline-2 focus-visible:outline-blue">Remove Mac</button>
                      </form>
                    </li>
                  ))}
                </ul>
              ) : <p className="mt-5 bg-mist p-5 text-ink-soft">Your first Mac will appear here after you activate LocalBolo.</p>}
            </section>
          </>
        ) : profile ? (
          <p className="mt-6 text-lg text-ink-soft">This license is no longer active. Check the purchase in <a href={appSumoProducts} rel="noreferrer" className="underline underline-offset-4">AppSumo My Products</a>, or contact us for help.</p>
        ) : !unavailable ? (
          <>
            <p className="mt-6 max-w-xl text-lg text-ink-soft">Open LocalBolo in AppSumo My Products, then choose Activate. You’ll return here to get your key and manage your Macs.</p>
            <a href={appSumoProducts} rel="noreferrer" className={`${button} mt-8`}>Open AppSumo My Products</a>
          </>
        ) : null}

        {session && !confirming && <form method="post" action="/appsumo/signout" className="mt-10"><input type="hidden" name="csrf" value={session.nonce as string} /><button className="min-h-11 text-sm underline underline-offset-4 hover:text-blue">Hide my license</button></form>}
        <p className="mt-10 text-sm text-ink-faint">Need help? Email <a href={`mailto:${site.supportEmail}`} className="underline underline-offset-4 hover:text-ink">{site.supportEmail}</a>. Include your AppSumo license ID from My Products.</p>
      </main>
      <SiteFooter />
    </>
  );
}
