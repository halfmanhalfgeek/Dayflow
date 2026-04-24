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

## Step 2 — Merge upstream into main

```bash
git merge upstream/main
```

If the merge produces conflicts:
1. Run `git status` to identify conflicting files and list them for the user
2. For each conflict, check whether it affects a locally customised file (see Step 4 for the list). If so, advise the user that their customisation may need manual resolution and show the conflict markers
3. Do NOT auto-resolve conflicts — stop and wait for user guidance

If the merge succeeds cleanly, continue.

---

## Step 3 — Security review of upstream changes

The upstream repository has previously had issues with API key leakage, unencrypted secret storage, and excessive telemetry. Review the incoming changes:

```bash
git diff HEAD^1..HEAD
```

Scan the diff for the following and report any findings:

### Critical — API key / secret exposure
- API keys or tokens in URL query strings (`?key=`, `?token=`, `?api_key=`)
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

Report findings as a categorised list. If any Critical or High issues are found, warn the user clearly and ask whether to continue or stop.

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

# JournalView — no lock gate (expected: 0)
grep -c "lockScreen" Dayflow/Dayflow/Views/UI/JournalView.swift
```

### 4c — Security fixes

```bash
# API keys must be in headers, not URL query strings
grep "key=.*apiKey\|?key=" Dayflow/Dayflow/Core/AI/GeminiDirectProvider.swift
grep "key=.*apiKey\|?key=" Dayflow/Dayflow/Core/AI/GemmaBackupProvider.swift
grep "key=.*apiKey\|?key=" Dayflow/Dayflow/Utilities/GeminiAPIHelper.swift
# Expected: no matches

# KeychainManager — print only in DEBUG
grep -A1 "print(" Dayflow/Dayflow/Core/Security/KeychainManager.swift

# AnalyticsService — opt-in default is false, "host" in blocked set
grep -A2 'optInKey.*nil' Dayflow/Dayflow/System/AnalyticsService.swift
grep '"host"' Dayflow/Dayflow/System/AnalyticsService.swift

# SentryHelper — beforeSend hook strips user/server/paths
grep "beforeSend\|serverName\|user = nil" Dayflow/Dayflow/Utilities/SentryHelper.swift
```

If any customisation is missing or has been reverted by the merge, report the specific issue to the user. **Do NOT proceed to build until the user confirms all customisations are correct.**

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
git merge upstream/main                 # resolve conflicts if any
# → run security review and customisation checks
rm -rf ./build && ./build.sh
rm -rf /Applications/Dayflow.app && cp -r ./build/Build/Products/Release/Dayflow.app /Applications/
git push origin main
```
