import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { releaseNotesHtml, type ChangelogEntry } from "./release-notes.ts";

const changelog: ChangelogEntry[] = [
  { version: "0.3.0", date: "November 2, 2026", changes: ["Dictate in Spanish.", "Fixes a crash when <fn> is held."] },
  { version: "0.2.1", date: "October 1, 2026", changes: ["The website is now localbolo.app."] },
  { version: "0.2.0", date: "September 30, 2026", changes: ["LocalBolo updates itself."] },
  { version: "0.1.0", date: "September 28, 2026", changes: ["Hold fn to dictate."] },
];
const builds = new Map([
  ["0.3.0", "5"],
  ["0.2.1", "3"],
  ["0.2.0", "2"],
]);

describe("releaseNotesHtml", () => {
  test("lists the update and every earlier version, newest first, marked with their builds", () => {
    const html = releaseNotesHtml("0.3.0", changelog, builds);

    const sections = [...html.matchAll(/<section( data-sparkle-version="(\d+)")?><h3>Version ([\d.]+)/g)];
    assert.deepEqual(
      sections.map((match) => [match[3], match[2]]),
      [
        ["0.3.0", "5"],
        ["0.2.1", "3"],
        ["0.2.0", "2"],
        ["0.1.0", undefined],
      ],
    );
    assert.match(html, /<h3>Version 0\.3\.0 · November 2, 2026<\/h3><ul><li>Dictate in Spanish\.<\/li>/);
  });

  test("hides the installed version and everything older", () => {
    const html = releaseNotesHtml("0.3.0", changelog, builds);

    assert.match(html, /\.sparkle-installed-version, \.sparkle-installed-version ~ section \{ display: none; \}/);
  });

  test("starts at the version being offered, leaving out newer ones", () => {
    const html = releaseNotesHtml("0.2.1", changelog, builds);

    assert.doesNotMatch(html, /0\.3\.0/);
    assert.match(html, /Version 0\.2\.1/);
  });

  test("escapes the text", () => {
    const html = releaseNotesHtml("0.3.0", changelog, builds);

    assert.match(html, /Fixes a crash when &#60;fn&#62; is held\./);
  });

  test("never links anywhere", () => {
    assert.doesNotMatch(releaseNotesHtml("0.3.0", changelog, builds), /<a |https?:\/\//);
  });

  test("falls back to a general note for a version missing from the changelog", () => {
    const html = releaseNotesHtml("9.9.9", changelog, builds);

    assert.match(html, /<p>This update includes improvements and fixes\.<\/p>/);
    assert.doesNotMatch(html, /<section/);
  });
});
