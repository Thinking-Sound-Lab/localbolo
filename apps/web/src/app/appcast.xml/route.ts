import { releases as changelog } from "@/lib/changelog";
import { releaseNotesHtml } from "@/lib/release-notes";
import { listReleases, type Release, type SparkleUpdate } from "@/lib/releases";
import { site } from "@/lib/site";

/** Rebuilt every ten minutes, so a new release reaches the app shortly after it's published. */
export const revalidate = 600;

/**
 * The update feed Sparkle checks inside the Mac app, in Sparkle's appcast
 * format. It lists every GitHub release signed for Sparkle; the app installs
 * one only if its signature matches the app's public key. The notes in the
 * update window come from the changelog (see src/lib/release-notes.ts).
 */
export async function GET() {
  // If GitHub can't be read, offer no updates rather than fail; the app checks again later.
  const updates = ((await listReleases()) ?? []).filter(
    (release): release is Release & { update: SparkleUpdate } => release.update !== undefined,
  );
  const builds = new Map(updates.map((release) => [release.version, release.update.build]));
  const items = updates.map((release) => item(release, builds)).join("");

  const feed = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>${site.name}</title>
    <link>${site.url}</link>
    <description>Updates for ${site.name} for Mac.</description>
    <language>en</language>${items}
  </channel>
</rss>
`;

  return new Response(feed, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
}

function item(release: Release & { update: SparkleUpdate }, builds: ReadonlyMap<string, string>) {
  const { update } = release;
  const notes = releaseNotesHtml(release.version, changelog, builds);
  return `
    <item>
      <title>${escapeXml(`${site.name} ${release.version}`)}</title>
      <pubDate>${new Date(release.publishedAt).toUTCString()}</pubDate>
      <sparkle:version>${escapeXml(update.build)}</sparkle:version>
      <sparkle:shortVersionString>${escapeXml(release.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${escapeXml(update.minimumSystemVersion)}</sparkle:minimumSystemVersion>
      <description><![CDATA[${notes.replaceAll("]]>", "]]]]><![CDATA[>")}]]></description>
      <sparkle:fullReleaseNotesLink>${escapeXml(`${site.url}/changelog`)}</sparkle:fullReleaseNotesLink>
      <enclosure url="${escapeXml(`${site.url}/download/${release.tag}`)}" length="${escapeXml(update.length)}" type="application/octet-stream" sparkle:edSignature="${escapeXml(update.edSignature)}"/>
    </item>`;
}

function escapeXml(text: string) {
  return text.replace(/[<>&"']/g, (character) => `&#${character.charCodeAt(0)};`);
}
