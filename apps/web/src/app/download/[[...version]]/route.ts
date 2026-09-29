import { downloadDiskImage, findRelease } from "@/lib/releases";
import { site } from "@/lib/site";

/**
 * Downloads the Mac app: /download for the newest version, or
 * /download/v0.2.0 for a specific one (the update feed links there). Anyone
 * can download it; it asks for a license key before it works.
 */
export async function GET(_request: Request, context: RouteContext<"/download/[[...version]]">) {
  const { version } = await context.params;
  const release = await findRelease(version?.[0]);
  if (!release) {
    return unavailable(version ? `There's no ${site.name} ${version[0]}.` : "There's no version to download yet.", 404);
  }

  return (
    (await downloadDiskImage(release)) ??
    unavailable("Downloads aren't available right now. Please try again in a minute.", 503)
  );
}

function unavailable(message: string, status: number) {
  return new Response(`${message} Questions? Write to ${site.supportEmail}.\n`, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
