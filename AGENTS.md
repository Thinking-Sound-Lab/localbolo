# Working on LocalBolo

LocalBolo is a macOS dictation app (`apps/mac`, Swift 6 with SwiftUI and AppKit) and its
marketing site (`apps/web`, Next.js). See the [README](README.md) for how everything fits
together.

## Check your work locally

Pull requests only run the website checks in CI. The Mac build and tests run once, in the
merge queue, because macOS CI minutes are expensive. So run the checks for whatever you changed
before you push:

```sh
# Mac app (from apps/mac)
xcodebuild test -project LocalBolo.xcodeproj -scheme "LocalBolo Dev" \
  -destination 'platform=macOS,arch=arm64' -skipPackagePluginValidation -quiet

# Website (from apps/web)
pnpm lint && pnpm build
```

If you change code that only compiles in Release (the `LocalBolo` scheme), also build it:

```sh
xcodebuild build -project LocalBolo.xcodeproj -scheme LocalBolo -configuration Release \
  -destination 'generic/platform=macOS' -skipPackagePluginValidation -quiet \
  ARCHS=arm64 CODE_SIGNING_ALLOWED=NO
```

## Pull requests

- `main` is protected. Open a pull request and queue it with `gh pr merge <number>`. The merge
  queue runs the full check and merges it if it passes.
- Keep pushes to a pull request purposeful: each push re-runs CI and restarts review.
- Don't trigger the full CI manually (`workflow_dispatch`) unless you've been asked to.
