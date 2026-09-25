#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/plugin-common.sh"

SOURCE=https://github.com/voyagen/oma-dots.git
REPLACE=
UPDATE=false
usage() {
  echo 'Usage: ./install.sh [--replace <current-workspace-widget-id>] [--update] [--source <git-url-or-path>]'
}
while (($#)); do
  case $1 in
    --replace) (($# >= 2)) || fail '--replace requires a widget ID'; REPLACE=$2; shift 2 ;;
    --update) UPDATE=true; shift ;;
    --source) (($# >= 2)) || fail '--source requires a Git repository'; SOURCE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

require_commands
source_config=$(config_source)
check_config "$source_config"
check_state
[[ ! -L $PLUGIN_DIR ]] || fail "refusing symlinked plugin directory: $PLUGIN_DIR"
[[ ! -f $STATE || -e $PLUGIN_DIR ]] || fail "plugin is missing but restore state exists; run ./uninstall.sh first"

if [[ -f $STATE ]]; then
  previous=$(jq -r '.replaced.entry | if type == "object" then .id else . end' "$STATE")
  [[ -z $REPLACE || $REPLACE == "$previous" ]] || fail "restore state already tracks $previous; cannot replace $REPLACE"
  REPLACE=
fi

location=
if [[ -n $REPLACE ]]; then
  [[ $REPLACE != "$PLUGIN_ID" ]] || fail 'cannot replace this plugin with itself'
  [[ -e $PLUGIN_DIR ]] || fail "run ./install.sh and verify the new dots on the bar before replacing $REPLACE"
  omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled == true)' >/dev/null ||
    fail "enable $PLUGIN_ID and verify its dots on the bar before replacing $REPLACE"
  found=$(locations "$source_config" "$REPLACE")
  [[ $(jq 'length' <<<"$found") == 1 ]] || fail "expected exactly one $REPLACE bar entry; no configuration changed"
  location=$(jq -c '.[0]' <<<"$found")
fi
if [[ -f $CONFIG && ( -n $REPLACE || ! -e $PLUGIN_DIR ) ]]; then
  backup=$(mktemp "${CONFIG}.oma-dots.bak.XXXXXX")
  cp -p -- "$CONFIG" "$backup" || { rm -f -- "$backup"; fail 'could not back up shell config'; }
  printf 'Original shell config backed up at %s\n' "$backup"
fi

stage=
created=false
replacement_started=false
completed=false
cleanup() {
  if [[ $created == true && $completed == false && $replacement_started == false && -e $PLUGIN_DIR ]]; then
    omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    omarchy plugin remove "$PLUGIN_ID" --yes >/dev/null 2>&1 ||
      printf 'Failed to roll back plugin installation; inspect %s\n' "$PLUGIN_DIR" >&2
  fi
  if [[ -n $stage ]]; then rm -rf -- "$stage"; fi
}
trap cleanup EXIT
trap 'exit 1' INT TERM

if [[ -e $PLUGIN_DIR ]]; then
  [[ -f $PLUGIN_DIR/manifest.json ]] || fail "existing directory is not a plugin: $PLUGIN_DIR"
  jq -e --arg id "$PLUGIN_ID" '.id == $id' "$PLUGIN_DIR/manifest.json" >/dev/null || fail 'plugin directory belongs to another plugin'
  if [[ $UPDATE == true ]]; then
    [[ -d $PLUGIN_DIR/.git ]] || fail 'local copy is not Git-managed; refusing to overwrite it'
    [[ -z $(git -C "$PLUGIN_DIR" status --porcelain) ]] || fail 'installed checkout has local changes; refusing update'
    omarchy plugin update "$PLUGIN_ID" --yes
  fi
  if [[ -z $REPLACE ]]; then
    echo "Existing $PLUGIN_ID left in place; no bar entries moved or overwritten."
    completed=true
    exit 0
  fi
else
  [[ $UPDATE == false ]] || fail 'plugin is not installed; omit --update for initial installation'
  omarchy-git-url-check "$SOURCE"
  stage=$(mktemp -d "${TMPDIR:-/tmp}/oma-dots.XXXXXX")
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}" git clone -- "$SOURCE" "$stage/repo"
  omarchy plugin validate "$stage/repo"
  jq -e --arg id "$PLUGIN_ID" '.id == $id' "$stage/repo/manifest.json" >/dev/null ||
    fail "source Git HEAD must declare $PLUGIN_ID; commit the new manifest before installing"
  created=true
  omarchy plugin add "$stage/repo" --yes
  git -C "$PLUGIN_DIR" remote set-url origin "$SOURCE"
fi

wait_for_plugin || fail "plugin discovery timed out; $PLUGIN_ID was not enabled"
# No placement argument: an existing widget retains its user-defined position.
if ! omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled == true)' >/dev/null; then
  omarchy plugin enable "$PLUGIN_ID"
fi
wait_for_entry_count "$PLUGIN_ID" 1 ||
  fail "plugin entry was not saved to $CONFIG; previous widget not disabled"
check_config "$CONFIG"

if [[ -n $REPLACE ]]; then
  mkdir -p -- "$(dirname -- "$STATE")"
  temp=$(mktemp "${STATE}.tmp.XXXXXX")
  if ! jq -n --arg id "$PLUGIN_ID" --argjson replaced "$location" \
      '{version: 1, pluginId: $id, replaced: $replaced}' >"$temp"; then
    rm -f -- "$temp"
    fail 'could not record restore state'
  fi
  mv -- "$temp" "$STATE"
  replacement_started=true
  # Recheck in case the user changed the layout while plugin discovery ran.
  check_config "$CONFIG"
  [[ $(locations "$CONFIG" "$REPLACE") == "[$location]" ]] || fail "bar layout changed; restore state kept at $STATE; previous widget not disabled"
  omarchy plugin disable "$REPLACE" || fail "could not disable $REPLACE; restore state kept at $STATE"
  wait_for_entry_count "$REPLACE" 0 || fail "could not confirm $REPLACE removal; restore state kept at $STATE"
  wait_for_entry_count "$PLUGIN_ID" 1 || fail "plugin entry disappeared from $CONFIG; restore state kept at $STATE"
fi

completed=true
echo "Installed $PLUGIN_ID. Run ./uninstall.sh to restore the previous workspace widget."
