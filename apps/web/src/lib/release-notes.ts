/** One version in the changelog (src/lib/changelog.ts). */
export type ChangelogEntry = { version: string; date: string; changes: string[] };

/*
 * The notes in the Mac app's update window, built from the changelog rather
 * than GitHub's release notes, so people read what changed for them, never
 * pull requests or repository links.
 *
 * Each update lists its own version and every earlier one, each in a section
 * marked with its build number. Sparkle marks the section of the version this
 * Mac already has with `sparkle-installed-version`, and the style below hides
 * it and everything older, so the window shows exactly what's new here, even
 * after skipped updates.
 */

const style = `<style>
  :root { color-scheme: light dark; }
  body { font: 13px -apple-system, sans-serif; line-height: 1.45; margin: 0; }
  h3 { font-size: 13px; margin: 0 0 4px; }
  section + section { margin-top: 14px; }
  ul { margin: 0; padding-left: 18px; }
  li + li { margin-top: 3px; }
  .sparkle-installed-version, .sparkle-installed-version ~ section { display: none; }
</style>`;

/**
 * The update window's notes for `version`, as HTML. `builds` maps each
 * released version to its build number (CFBundleVersion).
 */
export function releaseNotesHtml(
  version: string,
  changelog: readonly ChangelogEntry[],
  builds: ReadonlyMap<string, string>,
) {
  const index = changelog.findIndex((entry) => entry.version === version);
  if (index === -1) return `${style}\n<p>This update includes improvements and fixes.</p>`;

  const sections = changelog.slice(index).map((entry) => {
    const build = builds.get(entry.version);
    const marker = build ? ` data-sparkle-version="${escapeHtml(build)}"` : "";
    const changes = entry.changes.map((change) => `<li>${escapeHtml(change)}</li>`).join("");
    return `<section${marker}><h3>Version ${escapeHtml(entry.version)} · ${escapeHtml(entry.date)}</h3><ul>${changes}</ul></section>`;
  });
  return `${style}\n${sections.join("\n")}`;
}

function escapeHtml(text: string) {
  return text.replace(/[<>&"]/g, (character) => `&#${character.charCodeAt(0)};`);
}
