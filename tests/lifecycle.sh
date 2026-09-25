#!/usr/bin/env bash
set -euo pipefail

project=$(dirname -- "$(dirname -- "${BASH_SOURCE[0]}")")
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" OMARCHY_PATH="$tmp/omarchy" PATH="$tmp/bin:$PATH"
mkdir -p "$HOME/.config/omarchy" "$OMARCHY_PATH/config/omarchy" "$tmp/bin" "$tmp/upstream"
cp -- "$project/manifest.json" "$project/Workspaces.qml" "$tmp/upstream/"
git -C "$tmp/upstream" init -q -b main
git -C "$tmp/upstream" config user.name Tester
git -C "$tmp/upstream" config user.email test@example.invalid
git -C "$tmp/upstream" add .
git -C "$tmp/upstream" commit -qm 'initial widget'
cat >"$OMARCHY_PATH/config/omarchy/shell.json" <<'JSON'
{"version":1,"bar":{"layout":{"left":[{"id":"omarchy.menu"},{"id":"omarchy.workspaces","marker":"original"}],"center":[],"right":[]}},"plugins":[]}
JSON
cat >"$tmp/bin/omarchy-shell" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1-} ${2-}" in
  'shell listPlugins') echo '[]' ;;
  'shell reloadConfig') echo ok ;;
  *) exit 1 ;;
esac
SH
cat >"$tmp/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$tmp/bin/omarchy-git-url-check" <<'SH'
#!/usr/bin/env bash
[[ ${1-} != -* && ${1-} != *'::'* ]]
SH
cat >"$tmp/bin/omarchy" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
id=voyagen.oma-dots
plugin="$HOME/.config/omarchy/plugins/$id"
config="$HOME/.config/omarchy/shell.json"
[[ $1 == plugin ]] || exit 1
case $2 in
  validate)
    jq -e '.schemaVersion == 1 and .entryPoints.barWidget == "Workspaces.qml"' "$3/manifest.json" >/dev/null
    ;;
  add)
    [[ $4 == --yes ]] || exit 1
    mkdir -p -- "$(dirname -- "$plugin")"
    git clone -q -- "$3" "$plugin"
    jq -e --arg id "$id" '.id == $id and .entryPoints.barWidget == "Workspaces.qml"' "$plugin/manifest.json" >/dev/null
    echo 0 >"$HOME/.discovery"
    [[ ${MOCK_FAIL_ADD:-0} != 1 ]] || exit 1
    ;;
  list)
    if [[ ! -d $plugin ]]; then echo '[]'; exit; fi
    seen=$(<"$HOME/.discovery")
    echo "$((seen + 1))" >"$HOME/.discovery"
    if ((seen < 2)); then echo '[]'; exit; fi
    if [[ -f $config ]] && jq -e --arg id "$id" '[.bar.layout[][] | if type == "object" then .id else . end] | index($id) != null' "$config" >/dev/null; then
      printf '[{"id":"%s","enabled":true}]\n' "$id"
    else
      printf '[{"id":"%s","enabled":false}]\n' "$id"
    fi
    ;;
  enable)
    [[ ${MOCK_FAIL_ENABLE:-0} != 1 ]] || exit 1
    [[ -f $config ]] || cp -- "$OMARCHY_PATH/config/omarchy/shell.json" "$config"
    t=$(mktemp "${config}.tmp.XXXXXX")
    jq --arg id "$3" '.bar.layout.left += [{id:$id}]' "$config" >"$t"
    mv -- "$t" "$config"
    ;;
  disable)
    [[ ${MOCK_FAIL_DISABLE:-0} != 1 || $3 == "$id" ]] || exit 1
    [[ -f $config ]] || exit 1
    t=$(mktemp "${config}.tmp.XXXXXX")
    jq --arg id "$3" '.bar.layout |= with_entries(.value |= map(select((if type == "object" then .id else . end) != $id)))' "$config" >"$t"
    mv -- "$t" "$config"
    ;;
  update)
    git -C "$plugin" fetch -q origin HEAD
    git -C "$plugin" merge -q --ff-only FETCH_HEAD
    ;;
  remove)
    [[ $4 == --yes ]] || exit 1
    if [[ -f $config ]]; then
      t=$(mktemp "${config}.tmp.XXXXXX")
      jq --arg id "$id" '.bar.layout |= with_entries(.value |= map(select((if type == "object" then .id else . end) != $id)))' "$config" >"$t"
      mv -- "$t" "$config"
    fi
    rm -rf -- "$plugin"
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$tmp/bin/omarchy" "$tmp/bin/omarchy-shell" "$tmp/bin/omarchy-git-url-check" "$tmp/bin/hyprctl"

plugin="$HOME/.config/omarchy/plugins/voyagen.oma-dots"
config="$HOME/.config/omarchy/shell.json"
state="$HOME/.config/omarchy/.voyagen.oma-dots.restore.json"
assert() { jq -e "$1" "$config" >/dev/null || { echo "failed: $1" >&2; exit 1; }; }

# Fresh replacement is refused until the dots have been installed and checked.
if "$project/install.sh" --replace omarchy.workspaces; then echo 'unchecked replacement succeeded' >&2; exit 1; fi
"$project/install.sh" --source "$tmp/upstream"
assert '.bar.layout.left | map(.id) == ["omarchy.menu","omarchy.workspaces","voyagen.oma-dots"]'
"$project/install.sh" --replace omarchy.workspaces
assert '.bar.layout.left | map(.id) == ["omarchy.menu","voyagen.oma-dots"]'
[[ -f $state ]] && jq -e '.replaced.entry.marker == "original"' "$state" >/dev/null
# Preserve unrelated changes made after installation, even during uninstall.
t=$(mktemp); jq '.bar.layout.right += [{id:"user.clock"}]' "$config" >"$t"; mv "$t" "$config"
"$project/uninstall.sh"
assert '.bar.layout.left[1] == {"id":"omarchy.workspaces","marker":"original"}'
assert '.bar.layout.right == [{"id":"user.clock"}]'
[[ ! -f $state && ! -d $plugin ]]

# A manifestless custom workspace module must come back with all its settings.
t=$(mktemp); jq '.bar.layout.left[1] = {id:"my.workspace",type:"qml",source:"/home/user/custom.qml",settings:{color:"red"}}' "$config" >"$t"; mv "$t" "$config"
"$project/install.sh" --source "$tmp/upstream"
"$project/install.sh" --replace my.workspace
assert '([.bar.layout[][] | .id] | index("my.workspace")) == null'
# Repeat installation must neither overwrite local edits nor move the existing widget.
printf '\n// local edit\n' >>"$plugin/Workspaces.qml"
"$project/install.sh" --source "$tmp/upstream" --replace my.workspace
[[ $(git -C "$plugin" status --porcelain) == *Workspaces.qml* ]]
if "$project/uninstall.sh"; then echo 'dirty checkout was removed' >&2; exit 1; fi
git -C "$plugin" restore -- Workspaces.qml
"$project/uninstall.sh"
assert '.bar.layout.left[1] == {"id":"my.workspace","type":"qml","source":"/home/user/custom.qml","settings":{"color":"red"}}'

# A failed enable must roll back the new clone and not disable the old widget.
if MOCK_FAIL_ENABLE=1 "$project/install.sh" --source "$tmp/upstream"; then
  echo 'failed enable returned success' >&2; exit 1
fi
[[ ! -d $plugin && ! -f $state ]]
assert '.bar.layout.left[1].id == "my.workspace"'

"$project/install.sh" --source "$tmp/upstream"
# A failed disable keeps the restore record; uninstall repairs the interruption.
if MOCK_FAIL_DISABLE=1 "$project/install.sh" --replace my.workspace; then
  echo 'failed disable returned success' >&2; exit 1
fi
[[ -f $state && -d $plugin ]]
"$project/uninstall.sh"
assert '.bar.layout.left[1].id == "my.workspace"'

# Git updates do not reposition the widget or replace restore metadata.
"$project/install.sh" --source "$tmp/upstream"
"$project/install.sh" --replace my.workspace
t=$(mktemp); jq '.version = "2.1.0"' "$tmp/upstream/manifest.json" >"$t"; mv "$t" "$tmp/upstream/manifest.json"
git -C "$tmp/upstream" add manifest.json
git -C "$tmp/upstream" commit -qm 'update widget'
"$project/install.sh" --update
jq -e '.version == "2.1.0"' "$plugin/manifest.json" >/dev/null
assert '.bar.layout.left | map(.id) == ["omarchy.menu","voyagen.oma-dots"]'
"$project/uninstall.sh"
assert '.bar.layout.left[1].id == "my.workspace"'

# If the former widget was independently customized, refuse to delete the plugin.
"$project/install.sh" --source "$tmp/upstream"
"$project/install.sh" --replace my.workspace
t=$(mktemp); jq '.bar.layout.left += [{id:"my.workspace",type:"qml",source:"changed.qml"}]' "$config" >"$t"; mv "$t" "$config"
if "$project/uninstall.sh"; then echo 'conflicting user entry was overwritten' >&2; exit 1; fi
[[ -d $plugin && -f $state ]]
t=$(mktemp); jq '.bar.layout.left |= map(select(.id != "my.workspace"))' "$config" >"$t"; mv "$t" "$config"
"$project/uninstall.sh"
assert '.bar.layout.left[1] == {"id":"my.workspace","type":"qml","source":"/home/user/custom.qml","settings":{"color":"red"}}'

# Keeping an existing workspace widget is explicit, and uninstall must leave it alone.
"$project/install.sh" --source "$tmp/upstream"
assert '.bar.layout.left | map(.id) == ["omarchy.menu","my.workspace","voyagen.oma-dots"]'
[[ ! -f $state ]]
"$project/uninstall.sh"
assert '.bar.layout.left | map(.id) == ["omarchy.menu","my.workspace"]'

# Migration from the old plugin ID keeps the old files usable for rollback.
legacy="$HOME/.config/omarchy/plugins/voyagen.workspaces-dots"
mkdir -p "$legacy"
t=$(mktemp); jq '.id = "voyagen.workspaces-dots"' "$tmp/upstream/manifest.json" >"$t"; mv "$t" "$legacy/manifest.json"
cp -- "$tmp/upstream/Workspaces.qml" "$legacy/Workspaces.qml"
t=$(mktemp); jq '.bar.layout.left[1] = {id:"voyagen.workspaces-dots",settings:{color:"green"}}' "$config" >"$t"; mv "$t" "$config"
"$project/install.sh" --source "$tmp/upstream"
"$project/install.sh" --replace voyagen.workspaces-dots
assert '.bar.layout.left | map(.id) == ["omarchy.menu","voyagen.oma-dots"]'
"$project/uninstall.sh"
assert '.bar.layout.left[1] == {"id":"voyagen.workspaces-dots","settings":{"color":"green"}}'
[[ -d $legacy ]]

# Failed native add after cloning must roll back, and invalid user JSON cannot be replaced.
if MOCK_FAIL_ADD=1 "$project/install.sh" --source "$tmp/upstream"; then
  echo 'partial native add returned success' >&2; exit 1
fi
[[ ! -d $plugin && ! -f $state ]]
assert '.bar.layout.left[1].id == "voyagen.workspaces-dots"'
t=$(mktemp); jq '.id = "wrong.id"' "$tmp/upstream/manifest.json" >"$t"; mv "$t" "$tmp/upstream/manifest.json"
git -C "$tmp/upstream" add manifest.json
git -C "$tmp/upstream" commit -qm 'unexpected published ID'
if "$project/install.sh" --source "$tmp/upstream"; then echo 'wrong plugin ID installed' >&2; exit 1; fi
[[ ! -d $plugin && ! -f $state ]]
printf '{invalid' >"$config"
if "$project/install.sh" --source "$tmp/upstream"; then echo 'invalid JSON was overwritten' >&2; exit 1; fi
[[ ! -d $plugin && $(<"$config") == '{invalid' ]]
echo 'Lifecycle scenarios passed.'
