import assert from "node:assert/strict";
import { afterEach, beforeEach, describe, mock, test } from "node:test";
import { findRelease, listReleases } from "./releases.ts";

describe("listReleases", () => {
  beforeEach(() => {
    // Failures are logged; keep the test output quiet.
    mock.method(console, "error", () => {});
  });
  afterEach(() => mock.restoreAll());

  test("is null when GitHub can't be reached", async () => {
    mock.method(globalThis, "fetch", async () => {
      throw new TypeError("fetch failed");
    });

    assert.equal(await listReleases(), null);
    assert.equal(await findRelease(), null);
  });

  test("is null when GitHub answers with an error", async () => {
    mock.method(globalThis, "fetch", async () => new Response("rate limited", { status: 403 }));

    assert.equal(await listReleases(), null);
  });

  test("is empty when nothing is published yet", async () => {
    mock.method(globalThis, "fetch", async () => Response.json([]));

    assert.deepEqual(await listReleases(), []);
    assert.equal(await findRelease(), undefined);
    assert.equal(await findRelease("v9.9.9"), undefined);
  });

  test("lists published releases that have a disk image, newest first", async () => {
    mock.method(globalThis, "fetch", async () =>
      Response.json([
        release("v0.3.0", { draft: true }),
        release("v0.2.1", {
          body: '<!-- sparkle version="0.2.1" build="3" minimumSystemVersion="15.0" sparkle:edSignature="c2lnbmF0dXJl" length="19500000" -->\nNotes',
        }),
        release("v0.2.0-beta", { prerelease: true }),
        release("v0.2.0", { assets: [] }),
        release("v0.1.0"),
      ]),
    );

    const releases = (await listReleases()) ?? [];

    assert.deepEqual(
      releases.map((release) => release.version),
      ["0.2.1", "0.1.0"],
    );
    assert.deepEqual(releases[0].update, {
      build: "3",
      minimumSystemVersion: "15.0",
      edSignature: "c2lnbmF0dXJl",
      length: "19500000",
    });
    assert.equal(releases[1].update, undefined);
    assert.equal(releases[0].diskImage.url, "https://github.com/downloads/v0.2.1/LocalBolo.dmg");
  });
});

// MARK: - Helpers

function release(
  tag: string,
  changes: { draft?: boolean; prerelease?: boolean; body?: string; assets?: object[] } = {},
) {
  return {
    tag_name: tag,
    draft: changes.draft ?? false,
    prerelease: changes.prerelease ?? false,
    published_at: "2026-10-01T00:00:00Z",
    body: changes.body ?? "Notes",
    assets: changes.assets ?? [
      { id: 1, name: "LocalBolo.dmg", browser_download_url: `https://github.com/downloads/${tag}/LocalBolo.dmg` },
    ],
  };
}
