import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import {
  AppSumoError, appSumoCookieOptions, appSumoCookies, appSumoHeaders, appSumoRedirectURI,
  checkAppSumoForm, openAppSumoCookie, readSmallBody,
} from "./appsumo.ts";
import { appSumoFailure } from "./appsumo-handlers.ts";

export function appSumoRedirect(error?: string) {
  const url = new URL("/appsumo", appSumoRedirectURI());
  if (error) url.searchParams.set("error", error);
  const response = NextResponse.redirect(url, 303);
  for (const [name, value] of Object.entries(appSumoHeaders)) response.headers.set(name, value);
  return response;
}
export async function appSumoForm(request: Request, purpose: "session" | "pending") {
  if (!request.headers.get("content-type")?.startsWith("application/x-www-form-urlencoded")) throw new AppSumoError(415, "invalid");
  const form = new URLSearchParams((await readSmallBody(request, 4096)).toString());
  const jar = await cookies();
  const state = openAppSumoCookie(purpose, jar.get(appSumoCookies[purpose])?.value);
  checkAppSumoForm(request, form, state);
  return { form, state: state! };
}
export function clearAppSumoCookie(response: NextResponse, purpose: "pending" | "session") {
  response.cookies.set(appSumoCookies[purpose], "", appSumoCookieOptions(0));
}
export function appSumoFormFailure(error: unknown, purpose: "pending" | "session") {
  if (error instanceof AppSumoError && error.status === 401 && error.reason === "expired") {
    const response = appSumoRedirect("expired");
    clearAppSumoCookie(response, purpose);
    return response;
  }
  return appSumoFailure(error);
}
