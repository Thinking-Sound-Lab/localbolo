import { randomBytes } from "node:crypto";
import {
  AppSumoError, appSumoCookieOptions, appSumoCookies, appSumoRateBucket, exchangeAppSumoCode,
  getAppSumoLicense, sealAppSumoCookie, type AppSumoProfile,
} from "@/lib/appsumo";
import { appSumoForm, appSumoFormFailure, appSumoRedirect, clearAppSumoCookie } from "@/lib/appsumo-forms";
import { appSumoRateLimit, appSumoRPC } from "@/lib/appsumo-store";

export const runtime = "nodejs";
export async function POST(request: Request) {
  let confirmed = false;
  try {
    const { state } = await appSumoForm(request, "pending");
    confirmed = true;
    if (typeof state.code !== "string") throw new AppSumoError(403, "expired");
    await appSumoRateLimit(appSumoRateBucket(request, "claim"), 6);
    const key = await exchangeAppSumoCode(state.code);
    await appSumoRateLimit("appsumo-api", 18);
    const authoritative = await getAppSumoLicense(key);
    if (authoritative.status === "inactive") throw new AppSumoError(409, "pending");
    if (authoritative.status !== "active") throw new AppSumoError(403, "inactive");
    const profile = await appSumoRPC<AppSumoProfile | null>("appsumo_claim", { p_key: key });
    if (!profile || profile.tier !== authoritative.tier || !profile.product_key) throw new AppSumoError(409, "pending");
    const response = appSumoRedirect();
    response.cookies.set(appSumoCookies.session, sealAppSumoCookie("session", { licenseId: profile.id, nonce: randomBytes(32).toString("hex") }, 1800), appSumoCookieOptions(1800));
    clearAppSumoCookie(response, "pending");
    return response;
  } catch (error) {
    if (!confirmed) return appSumoFormFailure(error, "pending");
    const response = appSumoRedirect(error instanceof AppSumoError ? error.reason : "unavailable");
    clearAppSumoCookie(response, "pending");
    return response;
  }
}
