---
name: release-notes
description: Write the "what's new" notes for a LocalBolo release. Use whenever a new version of the Mac app is being prepared or released (bumping MARKETING_VERSION, tagging vX.Y.Z), or when asked to write or fix the changelog, release notes or update notes. The entry you write is what people read in the app's update window and on localbolo.app/changelog.
---

# Release notes for LocalBolo

Every release of the Mac app needs an entry in `apps/web/src/lib/changelog.ts`. That one entry is
shown in two places:

- **The app's update window.** When someone clicks Check for Updates…, Sparkle shows the notes from
  the update feed (`/appcast.xml`), which builds them from this file (`src/lib/release-notes.ts`).
  It lists every version newer than the one installed, so someone who skipped updates sees all of
  them, and nothing they already have.
- **The website's changelog** at localbolo.app/changelog, which is also the update window's
  "Version History" link.

GitHub's release notes (pull requests, contributors, compare links) are for developers and are
never shown to users. The release workflow stops if the version being tagged has no entry here.

The people reading this are LocalBolo users, not developers. They want to know what's different
when they open the app, and whether they need to do anything.

## 1. Find what changed

List what was merged since the last release:

```sh
git fetch --tags origin
last=$(git describe --tags --abbrev=0 origin/main)
git log --oneline "$last"..origin/main
gh pr list --state merged --base main --search "merged:>$(git log -1 --format=%cs "$last")" \
  --json number,title,body --jq '.[] | "#\(.number) \(.title)"'
```

Read the pull request descriptions, and the diff when a description doesn't make the effect on
users clear. For each change, ask: **would someone using the app notice this?**

**Keep:**
- New features, settings, models or menu items.
- Changed behavior: anything that works differently from the last version.
- Fixed problems people could actually run into.
- Faster or lighter, when the difference is noticeable.
- Changes in what the app needs: macOS version, permissions, internet access.
- Changes to privacy, licensing or updates.
- Anything people have to do themselves, such as granting a new permission or downloading again.

**Leave out:** CI and release tooling, tests, refactors, code style, README and docs,
dependency updates with no visible effect, and website-only changes. A website change that changes
the app, like a new address the app now uses, counts as an app change.

If a release has no change users would notice, write one honest line, such as "Improves
reliability when the microphone is unplugged while dictating." Avoid a vague "Bug fixes and
improvements."

## 2. Write the entries

One entry per change, as a plain sentence or two:

- **Describe it from the user's side.** Say what they'll notice, not what the code does. Prefer
  "Dictation starts faster after waking your Mac" to "Preload the model on wake notifications."
- **Name things exactly as the app shows them.** Use the window, menu and setting names, with the
  same punctuation: Settings › License, Check for Updates…, the fn key.
- **Present tense, specific and short.** Start with what's new or what's fixed: "Fixes text pasting
  twice in Slack." State numbers when they help: "Whisper Small downloads are 30% smaller."
- **Say what to do,** if anything: "Open Settings › Models to switch."
- **Plain text only.** No links, URLs, pull request or issue numbers, commit hashes, GitHub
  usernames, file names, code names, or internal tools and services users never see. The update
  window shows the text exactly as written, without formatting. Dodo Payments may be named,
  because buyers deal with it directly.
- **Put the most noticeable change first,** new things before fixes. Aim for six entries or fewer
  by combining small related changes.
- **Write in the site's voice:** calm, friendly and direct. No exclamation marks or hype.

**Rewrites:**

| Don't write | Write |
| --- | --- |
| Add Sparkle-based auto-update (#7) | LocalBolo now updates itself. Check for Updates… is in the menu bar. |
| Fix race in LicenseManager.check() | Fixes the license sometimes asking to be checked again right after a successful check. |
| Bump FluidAudio to 0.9 | Parakeet transcribes long dictations about 20% faster. |
| Refactor PillController | *(leave it out: nobody notices)* |
| Misc fixes | Fixes the pill staying on screen after dictating into a full-screen app. |

## 3. Add the entry

Add it at the **top** of `releases` in `apps/web/src/lib/changelog.ts`:

```ts
{
  version: "0.3.0",          // the tag without the "v", always all three numbers
  date: "November 2, 2026",  // the day it will be released, written out like this
  changes: [
    "Dictate in Spanish and French. Choose the language in Settings › Models.",
    "Fixes the pill staying on screen after dictating into a full-screen app.",
  ],
},
```

In the same pull request, set `MARKETING_VERSION` in `apps/mac/Config/Base.xcconfig` to the same
version. Use the version numbers this way:
- **Patch** (0.2.1 → 0.2.2) for fixes only.
- **Minor** (0.2 → 0.3) when something new users can see is added.
- **Major** only for big changes, decided with the maintainer.

## 4. Check it

From `apps/web`:

```sh
pnpm test     # includes the update window's notes (src/lib/release-notes.test.ts)
pnpm dev      # then read http://localhost:3000/changelog as a user would
```

Read every entry once more and ask yourself: would someone who doesn't write code understand it,
and know whether they need to do anything?

## 5. Release

Follow AGENTS.md:
1. Open a pull request.
2. Merge it only when the maintainer asks.
3. Tag `vX.Y.Z` on `main` and push the tag. The maintainer approves the release on GitHub.

The website's hero and the update feed pick the version up within ten minutes of the GitHub release
being published. The release workflow fails early if `changelog.ts` has no entry for the tag.
