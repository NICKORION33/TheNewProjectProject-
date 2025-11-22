#!/usr/bin/env bash
# deploy_debian.sh
# Usage: sudo ./deploy_debian.sh <repo-dir>
# Example: sudo ./deploy_debian.sh /srv/niqwares-agent-framework
#
# Creates repository layout, installs minimal packages if missing (git, node, python),
# writes placeholder files from the framework, sets hooks executable, and runs bootstrap.

set -euo pipefail
IFS=$'\n\t'

REPO_DIR="${1:-./niqwares-agent-framework}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== NIQWARES framework deploy (Debian) =="
echo "Target repo dir: $REPO_DIR"

# ensure running as root or with sudo for package installs and permission changes
if [ "$(id -u)" -ne 0 ]; then
  echo "Note: not running as root. Some package installs may fail. Re-run with sudo if you want automatic installs."
fi

# Install basic packages if not present
ensure_cmd() {
  local cmd="$1"
  local pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Command $cmd not found. Installing package $pkg..."
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -qq
      apt-get install -y "$pkg"
    else
      echo "No apt-get available. Please install $pkg manually."
    fi
  else
    echo "Found $cmd"
  fi
}

ensure_cmd git git
ensure_cmd node nodejs
ensure_cmd npm npm
ensure_cmd python3 python3
ensure_cmd pwsh powershell

# Create repo layout
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

echo "Creating directory structure..."
mkdir -p src assets tests docs tooling backups/raw backups/meta changelogs logs/actions logs releases web migrations .github

# Save core files (placeholders or copy from script dir if present)
write_if_missing() {
  local path="$1"
  local content="$2"
  if [ ! -e "$path" ]; then
    echo "Writing $path"
    printf '%s\n' "$content" > "$path"
  else
    echo "File exists: $path"
  fi
}

# README placeholder (you probably already pasted the full README from chat)
write_if_missing README.md "# NIQWARES Universal Agent Development Framework\n\nSee AUTO_BOOTSTRAP.md and tooling/ for details."

# AUTO_BOOTSTRAP placeholder (should be replaced with your full AUTO_BOOTSTRAP.md)
write_if_missing AUTO_BOOTSTRAP.md "# AUTO_BOOTSTRAP\n\nPlace the full bootstrap rules here (see chat export)."

# example tooling files: copy the backup.ps1 & bootstrap.ps1 embedded here as text
write_if_missing tooling/backup.ps1 "<# tooling/backup.ps1 placeholder - paste the full PowerShell backup script here #>"
write_if_missing tooling/bootstrap.ps1 "<# tooling/bootstrap.ps1 placeholder - paste the full PowerShell bootstrap script here #>"

# agent-runner (bash-friendly note)
write_if_missing tooling/agent-runner-notes.txt "See tooling/agent-runner.ps1 for agent-runner. Add a bash wrapper if desired."

# Create sample .git/hooks/pre-commit
HOOK_DIR=".git/hooks"
if [ ! -d ".git" ]; then
  git init -q
  echo "Initialized empty git repo in $(pwd)/.git/"
fi
mkdir -p "$HOOK_DIR"
cat > ".git/hooks/pre-commit" <<'HOOK'
#!/usr/bin/env bash
# Simple pre-commit: warn if CHANGELOG.md not staged for non-doc changes
staged=$(git diff --cached --name-only)
echo "$staged" | grep -q "CHANGELOG.md" && exit 0
exceptions="^docs/|^tooling/|^README.md"
requires_changelog=0
while IFS= read -r f; do
  if ! echo "$f" | egrep -q "$exceptions"; then
    requires_changelog=1
    break
  fi
done <<< "$staged"
if [ "$requires_changelog" -eq 1 ]; then
  echo "Non-doc changes detected. Please update CHANGELOG.md with a short entry or use commit type 'chore'."
  # to enforce, uncomment: exit 1
fi
exit 0
HOOK
chmod +x .git/hooks/pre-commit

# Create initial logs and ensure write perms
touch logs/error.log logs/security.log
mkdir -p logs/actions
chmod -R u+rwX,g+rwX,o-rwx logs backups tooling

# Create initial bootstrap audit file (json)
BOOT_AUDIT="logs/actions/bootstrap_local_$(hostname)_$(date -u +%Y%m%dT%H%M%SZ).json"
cat > "$BOOT_AUDIT" <<JSON
{
  "ts": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent": "local-deploy",
  "step": "bootstrap",
  "host": "$(hostname)",
  "note": "Initial repo layout created via deploy_debian.sh"
}
JSON
echo "Wrote bootstrap audit: $BOOT_AUDIT"

echo "Done. Next recommended steps:"
echo " - Replace tooling/backup.ps1 and tooling/bootstrap.ps1 placeholders with the real scripts (paste from chat)."
echo " - Commit files: git add . && git commit -m \"chore: initial niqwares framework layout\""
echo " - Make sure PowerShell core (pwsh) is installed on Debian if you plan to run .ps1 scripts."
echo " - Optionally create a bash wrapper to run the agent-runner or run the PS runner via pwsh."
