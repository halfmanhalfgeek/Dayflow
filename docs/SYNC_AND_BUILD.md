# Syncing with Upstream & Building

A guide to pulling the latest upstream Dayflow changes while preserving your local modifications.

## Prerequisites

- Your fork is set up with `origin` pointing to your repository and `upstream` pointing to the original repository
- You're on the `main` branch locally
- GitHub access token is configured in your session for pushing to remote

### Verify Git Remotes

Verify remotes are configured:

```bash
git remote -v
```

You should see:

- `origin` → your fork (halfmanhalfgeek/Dayflow)
- `upstream` → original repo (JerryZLiu/Dayflow)

### Set Up GitHub Access Token

To push to your remote, ensure your GitHub access token is in the session:

**Option 1: Store token in Git credentials (Recommended)**

```bash
# macOS: Use credential-osxkeychain
git config --global credential.helper osxkeychain

# Linux: Use credential-cache
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=3600'  # 1 hour timeout
```

When you run `git push` the first time, you'll be prompted for your username and password (use your GitHub token as the password).

**Option 2: Authenticate via SSH**

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Add public key to GitHub: https://github.com/settings/keys
cat ~/.ssh/id_ed25519.pub
```

Update remote URL to use SSH:

```bash
git remote set-url origin git@github.com:halfmanhalfgeek/Dayflow.git
```

**Option 3: Export token as environment variable (Session only)**

```bash
export GIT_ASKPASS_OVERRIDE=""
export GIT_TERMINAL_PROMPT=1
# Or set your token directly (less secure)
# export GITHUB_TOKEN="your_token_here"
```

**Option 4: Use GitHub CLI**

```bash
# Install GitHub CLI: https://cli.github.com
brew install gh

# Authenticate
gh auth login

# Git will automatically use your authenticated session
```

## Step 1: Fetch Latest Upstream Changes

```bash
git fetch upstream
```

This downloads the latest commits from the original repository without modifying your local code.

## Step 2: Merge Upstream into Your Branch

### Option A: Simple Merge (Recommended for most cases)

```bash
git merge upstream/main
```

This creates a merge commit combining upstream changes with your modifications. Git will automatically handle non-conflicting changes.

### Option B: Rebase (Cleaner history, use if you prefer linear commits)

```bash
git rebase upstream/main
```

This replays your local changes on top of the latest upstream code.

**Note:** If conflicts occur, you'll need to resolve them manually. See "Resolving Conflicts" below.

## Step 3: Push Your Updated Branch

```bash
git push origin main
```

This updates your fork with the merged/rebased code.

## Step 4: Build Locally

Once the merge is complete and clean, build the latest code with your extensions:

```bash
./build.sh
```

The script will:

- Clean the previous build
- Compile the Release version with your modifications
- Output the app to `./build/Build/Products/Release/Dayflow.app`

## Step 5: Run & Verify

Test the built application:

```bash
open ./build/Build/Products/Release/Dayflow.app
```

Or install to Applications folder:

```bash
cp -r ./build/Build/Products/Release/Dayflow.app /Applications/
```

---

## Resolving Conflicts

If `git merge` or `git rebase` reports conflicts:

1. **Identify conflicting files:**
   
   ```bash
   git status
   ```
   
   Look for files marked as "both modified"

2. **Open conflicting files** in your editor and find conflict markers:
   
   ```
   <<<<<<< HEAD
   Your local changes
   =======
   Upstream changes
   >>>>>>> upstream/main
   ```

3. **Edit to keep:**
   
   - Your local changes only
   - Upstream changes only
   - A combination of both

4. **Remove conflict markers** and save

5. **Mark as resolved:**
   
   ```bash
   git add <filename>
   ```

6. **Complete the merge:**
   
   ```bash
   git commit -m "Merge upstream/main with conflict resolution"
   ```
   
   Or if rebasing:
   
   ```bash
   git rebase --continue
   ```

---

## Full Workflow (Quick Reference)

```bash
# Fetch latest upstream
git fetch upstream

# Merge upstream changes
git merge upstream/main

# Resolve any conflicts (if needed)
# ... edit files, then:
# git add .
# git commit

# Push to your fork
git push origin main

# Build with your extensions
./build.sh

# Test
open ./build/Build/Products/Release/Dayflow.app
```

## Troubleshooting

**Changes don't appear after build:**

- Ensure the merge completed: `git log --oneline -5` should show upstream commits
- Clean the build: `rm -rf ./build` then run `./build.sh` again

**Lots of conflicts:**

- Consider starting fresh: `git reset --hard upstream/main` (WARNING: loses local changes)
- Or use a different branch to merge into first

**Need to undo a merge:**

```bash
git reset --hard HEAD~1
```

(Only if you haven't pushed yet)
