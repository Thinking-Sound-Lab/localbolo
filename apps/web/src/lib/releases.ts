/*
 * Published versions of the Mac app, read from the repository's GitHub
 * releases. The repository is private, so requests use a read-only token
 * (GITHUB_RELEASES_TOKEN) and the site hands out downloads itself.
 */

const repository = "Thinking-Sound-Lab/localbolo";
const diskImageName = "LocalBolo.dmg";
/** How often to look for new releases, in seconds. */
export const releasesRevalidateSeconds = 600;

/** What Sparkle needs to install a release, from the release notes' hidden comment. */
export type SparkleUpdate = {
  /** The app's build number (CFBundleVersion), which Sparkle compares. */
  build: string;
  minimumSystemVersion: string;
  edSignature: string;
  /** The disk image's size in bytes. */
  length: string;
};

export type Release = {
  /** For example "v0.2.0". */
  tag: string;
  /** For example "0.2.0". */
  version: string;
  publishedAt: string;
  notesHtml: string;
  diskImageId: number;
  /** Missing for releases made before the app could update itself. */
  update?: SparkleUpdate;
};

type GitHubRelease = {
  tag_name: string;
  draft: boolean;
  prerelease: boolean;
  published_at: string | null;
  body: string | null;
  body_html?: string;
  assets: { id: number; name: string }[];
};

/** Published releases, newest first. Empty when the token isn't set or GitHub can't be reached. */
export async function listReleases(): Promise<Release[]> {
  const headers = githubHeaders("application/vnd.github.full+json");
  if (!headers) return [];

  const response = await fetch(`https://api.github.com/repos/${repository}/releases?per_page=30`, {
    headers,
    next: { revalidate: releasesRevalidateSeconds },
  });
  if (!response.ok) {
    console.error(`Couldn't list GitHub releases: ${response.status}`);
    return [];
  }

  const releases = (await response.json()) as GitHubRelease[];
  return releases.flatMap((release) => {
    const diskImage = release.assets.find((asset) => asset.name === diskImageName);
    if (release.draft || release.prerelease || !diskImage || !release.published_at) return [];
    return [
      {
        tag: release.tag_name,
        version: release.tag_name.replace(/^v/, ""),
        publishedAt: release.published_at,
        notesHtml: release.body_html ?? "",
        diskImageId: diskImage.id,
        update: parseSparkleComment(release.body ?? ""),
      },
    ];
  });
}

/** The release with this tag or version, or the newest one. */
export async function findRelease(version?: string) {
  const releases = await listReleases();
  if (!version) return releases[0];
  return releases.find((release) => release.tag === version || release.version === version);
}

/**
 * A response that downloads the release's disk image, or null if GitHub
 * can't provide it. GitHub usually redirects to short-lived signed storage,
 * which works without the token; sometimes it sends the file itself.
 */
export async function downloadDiskImage(release: Release) {
  const headers = githubHeaders("application/octet-stream");
  if (!headers) return null;

  const response = await fetch(
    `https://api.github.com/repos/${repository}/releases/assets/${release.diskImageId}`,
    { headers, redirect: "manual", cache: "no-store" },
  );

  const location = response.headers.get("location");
  if (response.status >= 300 && response.status < 400 && location) {
    // The URL expires in minutes, so nothing should cache the redirect.
    return new Response(null, { status: 302, headers: { Location: location, "Cache-Control": "no-store" } });
  }
  if (response.ok && response.body) {
    const length = response.headers.get("content-length");
    return new Response(response.body, {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${diskImageName}"`,
        ...(length ? { "Content-Length": length } : {}),
      },
    });
  }

  console.error(`Couldn't download ${release.tag}'s disk image: ${response.status}`);
  return null;
}

function githubHeaders(accept: string) {
  const token = process.env.GITHUB_RELEASES_TOKEN;
  if (!token) return null;
  return {
    Accept: accept,
    Authorization: `Bearer ${token}`,
    "X-GitHub-Api-Version": "2022-11-28",
  };
}

/**
 * Reads the comment scripts/release-mac.sh puts at the top of the release
 * notes, such as
 * <!-- sparkle version="0.2.0" build="12" minimumSystemVersion="15.0" sparkle:edSignature="…" length="17700000" -->
 */
function parseSparkleComment(body: string): SparkleUpdate | undefined {
  const comment = body.match(/<!--\s*sparkle\s([^>]*)-->/)?.[1];
  if (!comment) return undefined;

  const attributes = Object.fromEntries(
    [...comment.matchAll(/([\w:]+)="([^"]*)"/g)].map(([, name, value]) => [name, value]),
  );
  const { build, minimumSystemVersion, length } = attributes;
  const edSignature = attributes["sparkle:edSignature"];
  if (!build || !minimumSystemVersion || !length || !edSignature) return undefined;
  return { build, minimumSystemVersion, edSignature, length };
}
