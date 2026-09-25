#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/plugin-common.sh"

(($# == 0)) || { echo 'Usage: ./uninstall.sh'; exit 2; }
require_commands
check_state
[[ ! -f $CONFIG ]] || check_config "$CONFIG"

validate_previous() {
  local previous count
  previous=$(locations "$CONFIG" "$old_id")
  count=$(jq 'length' <<<"$previous")
  if ((count > 0)); then
    [[ $count == 1 && $(jq -c '.[0].entry' <<<"$previous") == "$(jq -c '.replaced.entry' "$STATE")" ]] ||
      fail "$old_id was modified while this plugin was installed; restore manually from $STATE"
  fi
}


if [[ -f $STATE ]]; then
  [[ -f $CONFIG ]] || fail "missing shell config; restore state kept at $STATE"
  old_id=$(jq -r '.replaced.entry | if type == "object" then .id else . end' "$STATE")
  validate_previous
fi

if [[ -d $PLUGIN_DIR/.git && -n $(git -C "$PLUGIN_DIR" status --porcelain) ]]; then
  fail "installed checkout has local changes; save them before removing $PLUGIN_DIR"
fi

if [[ -d $PLUGIN_DIR ]]; then
  omarchy plugin remove "$PLUGIN_ID" --yes
fi
if [[ -f $CONFIG ]]; then
  wait_for_entry_count "$PLUGIN_ID" 0 || fail "plugin entry still present; restore state kept at $STATE"
fi


if [[ -f $STATE ]]; then
  # Plugin removal may already have updated shell.json; read it again and keep
  # every unrelated change made since installation.
  check_config "$CONFIG"
  validate_previous
  previous=$(locations "$CONFIG" "$old_id")
  if [[ $(jq 'length' <<<"$previous") == 0 ]]; then
    backup=$(mktemp "${CONFIG}.oma-dots.bak.XXXXXX")
    cp -p -- "$CONFIG" "$backup" || { rm -f -- "$backup"; fail 'could not back up shell config'; }
    temp=$(mktemp "${CONFIG}.tmp.XXXXXX")
    if ! jq -e --slurpfile state "$STATE" '
      $state[0].replaced as $old |
      .bar.layout[$old.section] as $entries |
      (if $old.index > ($entries | length) then ($entries | length) else $old.index end) as $index |
      .bar.layout[$old.section] = ($entries[:$index] + [$old.entry] + $entries[$index:])
    ' "$CONFIG" >"$temp"; then
      rm -f -- "$temp"
      fail "could not restore $old_id; restore state kept at $STATE"
    fi
    # Refuse to replace a concurrent user edit rather than silently erase it.
    cmp -s -- "$CONFIG" "$backup" || { rm -f -- "$temp"; fail "shell config changed; restore state kept at $STATE"; }
    mv -- "$temp" "$CONFIG"
    omarchy-shell shell reloadConfig >/dev/null || fail "restored $old_id on disk; restart shell manually; restore state kept at $STATE"
    printf 'Restored %s; prior shell config backed up at %s\n' "$old_id" "$backup"
  fi
  rm -- "$STATE"
else
  echo 'No recorded prior widget; existing bar layout left unchanged.'
fi

echo "Removed $PLUGIN_ID."
