import { listReleases, type Release, type SparkleUpdate } from "@/lib/releases";
import { site } from "@/lib/site";

/** Rebuilt every ten minutes, so a new release reaches the app shortly after it's published. */
export const revalidate = 600;

/**
 * The update feed Sparkle checks inside the Mac app, in Sparkle's appcast
 * format. It lists every GitHub release signed for Sparkle; the app installs
 * one only if its signature matches the app's public key.
 */
export async function GET() {
  // If GitHub can't be read, offer no updates rather than fail; the app checks again later.
  const items = ((await listReleases()) ?? [])
    .filter((release): release is Release & { update: SparkleUpdate } => release.update !== undefined)
    .map(item)
    .join("");

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

function item(release: Release & { update: SparkleUpdate }) {
  const { update } = release;
  return `
    <item>
      <title>${escapeXml(`${site.name} ${release.version}`)}</title>
      <pubDate>${new Date(release.publishedAt).toUTCString()}</pubDate>
      <sparkle:version>${escapeXml(update.build)}</sparkle:version>
      <sparkle:shortVersionString>${escapeXml(release.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${escapeXml(update.minimumSystemVersion)}</sparkle:minimumSystemVersion>
      <description><![CDATA[${release.notesHtml.replaceAll("]]>", "]]]]><![CDATA[>")}]]></description>
      <enclosure url="${escapeXml(`${site.url}/download/${release.tag}`)}" length="${escapeXml(update.length)}" type="application/octet-stream" sparkle:edSignature="${escapeXml(update.edSignature)}"/>
    </item>`;
}

function escapeXml(text: string) {
  return text.replace(/[<>&"']/g, (character) => `&#${character.charCodeAt(0)};`);
}
