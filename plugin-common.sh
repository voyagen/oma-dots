#!/usr/bin/env bash

PLUGIN_ID=voyagen.oma-dots
PLUGIN_DIR="${HOME:-}/.config/omarchy/plugins/$PLUGIN_ID"
CONFIG="${HOME:-}/.config/omarchy/shell.json"
DEFAULT_CONFIG="${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json"
STATE="${HOME:-}/.config/omarchy/.${PLUGIN_ID}.restore.json"

fail() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 1; }

require_commands() {
  local command
  for command in jq git omarchy omarchy-shell omarchy-git-url-check hyprctl; do
    command -v "$command" >/dev/null 2>&1 || fail "missing required command: $command"
  done
  [[ -n ${HOME:-} && -d $HOME ]] || fail 'HOME must name an existing directory'
  [[ ! -L $STATE ]] || fail "refusing symlinked restore state: $STATE"
  [[ ! -e $STATE || -f $STATE ]] || fail "restore state is not a regular file: $STATE"
  [[ ! -L $CONFIG ]] || fail "refusing symlinked shell config: $CONFIG"
  omarchy-shell shell listPlugins >/dev/null || fail 'omarchy-shell must be running in this session'
}

config_source() {
  if [[ -f $CONFIG ]]; then printf '%s\n' "$CONFIG"; else printf '%s\n' "$DEFAULT_CONFIG"; fi
}

check_config() {
  local source=$1
  [[ -f $source ]] || fail "missing shell config: $source"
  jq -e '.version == 1 and (.bar.layout | type == "object") and
    (.bar.layout.left | type == "array") and
    (.bar.layout.center | type == "array") and
    (.bar.layout.right | type == "array")' "$source" >/dev/null || fail "invalid shell config: $source"
}

# Locate the complete entry: custom command/QML widgets require more than their ID to restore.
locations() {
  local source=$1 id=$2
  jq -c --arg id "$id" '[.bar.layout as $layout |
    ["left", "center", "right"][] as $section |
    $layout[$section] | to_entries[] |
    select((.value | if type == "object" then .id else . end) == $id) |
    {section: $section, index: .key, entry: .value}]' "$source"
}

# IPC calls may finish before an atomic FileView write reaches shell.json.
wait_for_entry_count() {
  local id=$1 expected=$2 attempt found
  for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -f $CONFIG ]]; then
      found=$(locations "$CONFIG" "$id") || return 1
      [[ $(jq 'length' <<<"$found") == "$expected" ]] && return 0
    fi
    sleep 0.1
  done
  return 1
}

check_state() {
  [[ -f $STATE ]] || return 0
  jq -e --arg id "$PLUGIN_ID" '.version == 1 and .pluginId == $id and
    (.replaced.section as $section | ["left", "center", "right"] | index($section) != null) and
    (.replaced.index | type == "number") and .replaced.index >= 0 and
    (.replaced.entry | (if type == "object" then .id else . end) | type == "string" and . != "" and . != $id)' "$STATE" >/dev/null ||
    fail "invalid restore state: $STATE"
}

# Do not mistake a completed IPC rescan for completed asynchronous discovery.
wait_for_plugin() {
  local attempt
  for ((attempt = 0; attempt < 100; attempt++)); do
    if omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}
