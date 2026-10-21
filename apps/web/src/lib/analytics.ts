import type { BeforeSendEvent } from "@vercel/analytics/next";

/**
 * Removes what analytics must never see before a page view is sent. The
 * purchase page's address carries the buyer's payment ID, so it goes without
 * its query string.
 */
export function withoutPaymentDetails(event: BeforeSendEvent): BeforeSendEvent | null {
  const url = new URL(event.url);
  if (url.pathname === "/appsumo" || url.pathname.startsWith("/appsumo/")) return null;
  if (url.pathname !== "/purchase") return event;
  url.search = "";
  return { ...event, url: url.toString() };
}
