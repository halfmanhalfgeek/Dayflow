---
name: sync-and-build
description: Sync the Dayflow fork with upstream, merge changes, review for security issues, verify local customisations are intact, rebuild, and deploy. Use this skill whenever the user wants to pull upstream Dayflow updates, sync their fork, rebuild Dayflow, or deploy a new build to Applications. Also use when the user mentions updating from upstream, merging upstream, or building Dayflow.
---

# Sync and Build Dayflow

Automates the full upstream sync, security review, customisation verification, build, and deploy workflow for the Dayflow fork.

## Prerequisites

Before starting, confirm the working directory is the Dayflow repository root (should contain `build.sh`, `Dayflow/` directory, and `docs/`). Also confirm:
- The current branch is `main`
- Git remotes are configured: `origin` → `halfmanhalfgeek/Dayflow`, `upstream` → `JerryZLiu/Dayflow`

Run `git remote -v` and `git branch --show-current` to verify. If anything is wrong, stop and inform the user.

## Step 1 — Fetch upstream

```bash
git fetch upstream
```

After fetching, check whether there are any new commits to merge:

```bash
git log --oneline HEAD..upstream/main
```

If there are no new commits, inform the user that the fork is already up to date and skip to Step 5 (Build and Deploy) — the user may still want a fresh build.

## Step 2 — Merge upstream into main

```bash
git merge upstream/main
```

If the merge produces conflicts:
1. Run `git status` to identify conflicting files
2. List the conflicting files for the user
3. For each conflict, check whether it affects a locally customised file (see Step 4 for the list). If so, advise the user that their customisation may need manual resolution and show the conflict markers.
4. Do NOT auto-resolve conflicts. Stop and wait for user guidance.

If the merge succeeds cleanly, continue.

## Step 3 — Security review of upstream changes

Review the incoming upstream changes for security concerns. This is important because the upstream repository has previously had issues with API key leakage, unencrypted secret storage, and excessive telemetry.

Run:

```bash
git diff HEAD~1..HEAD --diff-filter=M
```

(If the merge commit has two parents, use `git diff HEAD^1..HEAD` to see what upstream introduced.)

Scan the diff for the following categories of issue, reporting any findings to the user:

### Critical — API key / secret exposure
- API keys or tokens appearing in URL query strings (e.g. `?key=`, `?token=`, `?api_key=`)
- Secrets written to `UserDefaults` instead of Keychain
- API keys or tokens logged via `print()`, `NSLog()`, or `os_log()` outside `#if DEBUG` blocks
- Hardcoded secrets or credentials in source

### High — Privacy / PII leakage
- New analytics events that capture PII (file paths, hostnames, URLs, usernames, clipboard content, screen content, window titles)
- Changes to the `AnalyticsService.sanitize()` method that remove keys from the blocked set
- Changes to `SentryHelper` that weaken PII scrubbing or re-enable `sendDefaultPii`
- Changes to the analytics opt-in default (must remain `false` — user must opt in)

### Medium — Network and data handling
- New outbound network calls to unfamiliar domains
- Unvalidated deep link / URL scheme handlers
- New file system access patterns that read outside the app sandbox
- Weakened code signing or entitlement changes

### Low — General hygiene
- New dependencies or frameworks added
- Debug logging left enabled in release paths (outside `#if DEBUG`)
- Removed or weakened input validation

Present findings as a categorised list. If any Critical or High issues are found, warn the user clearly and recommend reviewing before proceeding. Ask whether to continue or stop.

If no issues are found, confirm the changes look clean and continue.

## Step 4 — Verify local customisations are retained

After merging, verify that the fork's custom modifications are still in place. These are changes that differentiate this fork from upstream and must survive every merge.

### 4a — Scheduled recording system

Confirm these files exist and contain the expected code:

1. **`Dayflow/Dayflow/Core/Recording/RecordingScheduleManager.swift`** — must exist and contain the `RecordingScheduleManager` class with `shouldBeRecording()`, `evaluateSchedule()`, and `enforceSchedule()` methods.

2. **`Dayflow/Dayflow/Core/Recording/RecordingSchedulePreferences.swift`** — must exist and contain the `RecordingSchedule` struct and `RecordingSchedulePreferences` class.

3. **`Dayflow/Dayflow/App/PauseManager.swift`** — must contain the schedule-aware resume logic. Look for `RecordingScheduleManager.shared.shouldBeRecording()` in the resume path. The key change: when a schedule is active, recording only resumes if the schedule says so.

4. **`Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift`** — must contain `_ = RecordingScheduleManager.shared` to initialise the schedule manager timer on launch.

5. **`Dayflow/Dayflow/Views/UI/PausePillView.swift`** — must contain `@ObservedObject private var scheduleManager = RecordingScheduleManager.shared` and the `PillScheduleClockIcon` view. The pill must show a clock icon when schedule mode is active.

6. **`Dayflow/Dayflow/Views/UI/Settings/OtherSettingsViewModel.swift`** and **`Dayflow/Dayflow/Views/UI/Settings/SettingsOtherTabView.swift`** — must exist (these provide the UI for configuring the recording schedule).

### 4b — Unblocked features

7. **`Dayflow/Dayflow/Views/UI/DailyView.swift`** — must contain:
   ```swift
   @AppStorage("isDailyUnlocked") private var isUnlocked: Bool = true
   ```
   The default must be `true` (upstream uses `false`). This unlocks the Daily view without requiring the upstream unlock flow.

8. **`Dayflow/Dayflow/Views/UI/JournalView.swift`** — must show `unlockedContent` directly without the `if isUnlocked` / `else lockScreen` conditional gate. The body should render `unlockedContent` unconditionally.

### 4c — Security fixes

9. **`Dayflow/Dayflow/Core/AI/GeminiDirectProvider.swift`** — API keys must be sent via `X-Goog-Api-Key` header, not in URL query strings. Check that no method constructs URLs with `?key=`.

10. **`Dayflow/Dayflow/Core/AI/GemmaBackupProvider.swift`** — same as above: API key in header, not URL.

11. **`Dayflow/Dayflow/Utilities/GeminiAPIHelper.swift`** — same as above.

12. **`Dayflow/Dayflow/Core/Security/KeychainManager.swift`** — all `print()` calls in `retrieve()` must be inside `#if DEBUG` blocks.

13. **`Dayflow/Dayflow/System/AnalyticsService.swift`** — the `isOptedIn` getter must return `false` when no preference exists (opt-in, not opt-out). The `sanitize()` blocked set must include `"host"`.

14. **`Dayflow/Dayflow/Utilities/SentryHelper.swift`** — must contain a `beforeSend` hook that strips user object, server name, and home-directory paths.

### How to verify

Use `grep` to spot-check each file for the key markers described above. You do not need to read every file in full — targeted checks are sufficient. For example:

```bash
# Check DailyView unlock default
grep "isDailyUnlocked.*true" Dayflow/Dayflow/Views/UI/DailyView.swift

# Check JournalView has no lock gate
grep -c "lockScreen" Dayflow/Dayflow/Views/UI/JournalView.swift
# Expected: 0 (or only in dead code / comments)

# Check API keys not in URLs
grep "key=.*apiKey" Dayflow/Dayflow/Core/AI/GeminiDirectProvider.swift
# Expected: no matches

# Check analytics default is opt-in
grep -A2 "optInKey.*nil" Dayflow/Dayflow/System/AnalyticsService.swift
# Should show "return false"
```

If any customisation is missing or has been reverted by the merge, report the specific issue to the user. Do NOT proceed to build until the user confirms the customisations are correct.

If all checks pass, confirm to the user and continue.

## Step 5 — Build and deploy

### 5a — Kill running Dayflow instance

If Dayflow is currently running, it must be closed before replacing the app bundle:

```bash
pkill -x Dayflow 2>/dev/null || true
```

### 5b — Delete old build directory

```bash
rm -rf ./build
```

### 5c — Build

```bash
./build.sh
```

This runs `xcodebuild` with Release configuration, unsigned. It takes a few minutes. Monitor for build failures. If the build fails, show the user the error output and stop.

### 5d — Verify build output

Confirm the app bundle was created:

```bash
ls -la ./build/Build/Products/Release/Dayflow.app
```

### 5e — Deploy to Applications

Remove the existing app bundle first to avoid symlink conflicts with embedded frameworks (Sparkle, Sentry), then copy the fresh build:

```bash
rm -rf /Applications/Dayflow.app
cp -r ./build/Build/Products/Release/Dayflow.app /Applications/
```

Note: the first launch after copying may trigger a Gatekeeper warning. Right-click the app and select "Open" to bypass.

## Step 6 — Push to origin

After a successful build and deploy, push the merged changes to the fork:

```bash
git push origin main
```

## Summary

Once complete, report to the user:
- What upstream version was merged (tag or commit range)
- Whether any security issues were found in the upstream changes
- Whether all local customisations were verified intact
- Whether the build succeeded
- Whether the app was copied to Applications
