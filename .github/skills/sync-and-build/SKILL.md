---
name: sync-and-build
description: "Sync Dayflow with the upstream JerryZLiu/Dayflow repository and build locally. Use when: pulling upstream changes, updating from upstream, syncing fork, merging upstream, building after upstream update, updating build from upstream repository, deploying a new Dayflow build."
argument-hint: "Optional: branch or specific upstream ref to sync from (default: upstream/main)"
---

# Sync and Build Dayflow

Automates the full upstream sync, security review, customisation verification, build, and deploy workflow for the Dayflow fork.

## Prerequisites

Confirm the working directory is the Dayflow repository root (contains `build.sh`, `Dayflow/`, `docs/`). Also verify:

```bash
git remote -v
git branch --show-current
```

Expected:
- Branch: `main`
- `origin` → `halfmanhalfgeek/Dayflow`
- `upstream` → `JerryZLiu/Dayflow`

If `upstream` is not configured:
```bash
git remote add upstream https://github.com/JerryZLiu/Dayflow.git
```

If anything is wrong, stop and inform the user before continuing.

---

## Step 1 — Fetch upstream

```bash
git fetch upstream
```

Then check whether there are new commits to merge:

```bash
git log --oneline HEAD..upstream/main
```

If there are no new commits, inform the user that the fork is already up to date and skip to [Step 5](#step-5--build-and-deploy) — the user may still want a fresh build.

---

## Step 2 — Merge upstream and reapply the fork's security fixes

```bash
git merge --no-ff --no-commit upstream/main
```

Use the selected upstream ref in place of `upstream/main` when supplied. Use the upstream implementation as the starting point for changed behaviour, then reapply the fork's security fixes to that implementation. Check affected paths even when Git merges cleanly. Preserve fork customisations listed in Step 4.

- For conflicts covered by an existing fork security fix, take the upstream implementation for the conflicting change and reapply the security fix before staging it. For example, keep upstream's Gemini model-list request and send the key in the `X-Goog-Api-Key` header. Keep credentials out of URLs and logs, and update affected tests to verify the protected behaviour.
- For any conflict whose resolution remains unclear, run `git status`, report the conflicting files and relevant markers, and wait for user guidance.

Stage the resolutions and complete Steps 3 and 4 before committing the merge.

---

## Step 3 — Security review of upstream changes

The upstream repository has previously had issues with API key leakage, unencrypted secret storage, and excessive telemetry. Review the incoming changes and the staged result:

```bash
git diff HEAD...upstream/main
git diff --cached HEAD
```

Scan the diff for the following and report any findings:

### Critical — API key / secret exposure
- API keys or tokens in URL query strings, including parameters after `?` or `&`
- Secrets written to `UserDefaults` instead of Keychain
- API keys logged via `print()`, `NSLog()`, or `os_log()` outside `#if DEBUG` blocks
- Hardcoded secrets or credentials in source

### High — Privacy / PII leakage
- New analytics events capturing PII (file paths, hostnames, URLs, usernames, clipboard/screen/window content)
- Changes to `AnalyticsService.sanitize()` that remove keys from the blocked set
- Changes to `SentryHelper` that weaken PII scrubbing or re-enable `sendDefaultPii`
- Changes to the analytics opt-in default (must remain `false` — user must opt in)

### Medium — Network and data handling
- New outbound network calls to unfamiliar domains
- Unvalidated deep link / URL scheme handlers
- New file system access outside the app sandbox
- Weakened code signing or entitlement changes

### Low — General hygiene
- New dependencies or frameworks added
- Debug logging left enabled in release paths (outside `#if DEBUG`)
- Removed or weakened input validation

Report findings by severity, including upstream regressions corrected by reapplying fork security fixes. If any Critical or High issue remains in the staged result, warn the user clearly and ask whether to continue or stop.

---

## Step 4 — Verify local customisations are retained

These fork-specific modifications must survive every merge. Use targeted `grep` checks rather than reading full files.

### 4a — Scheduled recording system

```bash
# RecordingScheduleManager — key methods
grep -l "shouldBeRecording\|evaluateSchedule\|enforceSchedule" Dayflow/Dayflow/Core/Recording/RecordingScheduleManager.swift

# PauseManager — schedule-aware resume
grep "shouldBeRecording" Dayflow/Dayflow/App/PauseManager.swift

# ScreenRecorder — schedule manager initialised on launch
grep "RecordingScheduleManager.shared" Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift

# PausePillView — clock icon when schedule active
grep "PillScheduleClockIcon\|scheduleManager" Dayflow/Dayflow/Views/UI/PausePillView.swift
```

Also confirm these files exist:
- `Dayflow/Dayflow/Core/Recording/RecordingSchedulePreferences.swift`
- `Dayflow/Dayflow/Views/UI/Settings/OtherSettingsViewModel.swift`
- `Dayflow/Dayflow/Views/UI/Settings/SettingsOtherTabView.swift`

### 4b — Unblocked features

```bash
# DailyView — must default to true (unlocked)
grep "isDailyUnlocked.*true" Dayflow/Dayflow/Views/UI/DailyView.swift

# If an older ref still has JournalView, verify it has no lock gate.
# Journal has been retired on main.
if [ -f Dayflow/Dayflow/Views/UI/JournalView.swift ]; then
  grep -c "lockScreen" Dayflow/Dayflow/Views/UI/JournalView.swift
fi
```

### 4c — Security fixes

```bash
# Confirm header-based Gemini authentication in each file
grep -in 'X-Goog-Api-Key' Dayflow/Dayflow/Core/AI/GeminiDirectProvider*.swift \
  Dayflow/Dayflow/Core/AI/GemmaBackupProvider*.swift Dayflow/Dayflow/Utilities/GeminiAPIHelper.swift
# Expected no matches for credentials in URL query strings
grep -Ein '[?&](key|api[_-]?key|token|access_token)=|URLQueryItem.*"(key|api[_-]?key|token|access_token)"' \
  Dayflow/Dayflow/Core/AI/GeminiDirectProvider*.swift \
  Dayflow/Dayflow/Core/AI/GemmaBackupProvider*.swift Dayflow/Dayflow/Utilities/GeminiAPIHelper.swift

# KeychainManager — print only in DEBUG
grep -A1 "print(" Dayflow/Dayflow/Core/Security/KeychainManager.swift

# AnalyticsService — opt-in default is false, "host" in blocked set
grep -A2 'optInKey.*nil' Dayflow/Dayflow/System/AnalyticsService.swift
grep '"host"' Dayflow/Dayflow/System/AnalyticsService.swift

# SentryHelper — beforeSend hook strips user/server/paths
grep "beforeSend\|serverName\|user = nil" Dayflow/Dayflow/Utilities/SentryHelper.swift
```

If any customisation is missing or has been reverted by the merge, report the specific issue to the user. **Do NOT proceed to build until the user confirms all customisations are correct.**

Once the security review and customisation checks pass, commit the staged merge.

---

## Step 5 — Build and deploy

### 5a — Kill any running Dayflow instance

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

This runs `xcodebuild` in Release configuration (unsigned). If the build fails, show the user the error output and stop.

### 5d — Verify build output

```bash
ls -la ./build/Build/Products/Release/Dayflow.app
```

### 5e — Deploy to Applications

Remove the existing bundle first to avoid symlink conflicts with embedded frameworks (Sparkle, Sentry):

```bash
rm -rf /Applications/Dayflow.app
cp -r ./build/Build/Products/Release/Dayflow.app /Applications/
```

> Note: the first launch after copying may trigger a Gatekeeper warning. Right-click the app and select "Open" to bypass.

---

## Step 6 — Push to origin

```bash
git push origin main
```

---

## Summary

Once complete, report:
- What upstream commits were merged (commit range or tag)
- Whether any security issues were found in the upstream diff
- Whether all local customisations were verified intact
- Whether the build succeeded
- Whether the app was deployed to `/Applications/`

---

## Quick Reference

```bash
git fetch upstream
git log --oneline HEAD..upstream/main  # check for new commits
git merge --no-ff --no-commit upstream/main
# → take upstream updates, reapply fork security fixes, stage, review, and verify
git commit --no-edit
rm -rf ./build && ./build.sh
rm -rf /Applications/Dayflow.app && cp -r ./build/Build/Products/Release/Dayflow.app /Applications/
git push origin main
```
