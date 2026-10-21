import { randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { appSumoCookieOptions, appSumoCookies, appSumoHeaders, appSumoRedirectURI, sealAppSumoCookie } from "@/lib/appsumo";
import { appSumoFailure } from "@/lib/appsumo-handlers";

export const runtime = "nodejs";
export async function GET(request: Request) {
  const params = new URL(request.url).searchParams;
  // The Partner Portal probes this URL without an OAuth code.
  if (!params.has("code")) return new Response("LocalBolo AppSumo activation", { headers: appSumoHeaders });
  try {
    const code = params.get("code") ?? "";
    if (params.getAll("code").length !== 1 || !/^[A-Za-z0-9._~-]{8,512}$/.test(code)) {
      return new Response("Start activation again from AppSumo My Products.", { status: 400, headers: appSumoHeaders });
    }
    // A direct AppSumo redirect has no partner-initiated state. Stage it, then
    // require a same-origin, nonce-protected confirmation before login. A GET
    // cannot silently replace an existing buyer's session.
    const response = NextResponse.redirect(new URL("/appsumo?confirm=1", appSumoRedirectURI()), 303);
    for (const [name, value] of Object.entries(appSumoHeaders)) response.headers.set(name, value);
    response.cookies.set(appSumoCookies.pending, sealAppSumoCookie("pending", { code, nonce: randomBytes(32).toString("hex") }, 300), appSumoCookieOptions(300));
    return response;
  } catch (error) { return appSumoFailure(error); }
}
