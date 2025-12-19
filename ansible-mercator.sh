#!/usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p bash jq yq ansible 
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/871b9fd269ff6246794583ce4ee1031e1da71895.tar.gz
set -euo pipefail

# $1 = path to Ansible inventory
# $2 = path to cartography YAML

inventory_file="$1"
cartography_file="$2"

echo "Inventory: $inventory_file"
echo "Cartography: $cartography_file"

inventory_json=$(ansible-inventory --export -i "$inventory_file" --list)

get_children_group_vars() {
  local level="$1"
  jq -r --arg key "$level" '.[$key].children[]?' <<< "$inventory_json"
}

get_unexpected_group_vars() {
  local level="$1"

  local children_json
  children_json=$(printf '%s\n' "$level" | jq -R . | jq -s .)

  jq -r --argjson children "$children_json" '
    keys_unsorted[]
    | select(. as $k | $children | index($k) | not)
  ' <<< "$inventory_json"
}

get_vars_defined_at_group_vars() {
  local child="$1"
  jq -r --arg child "$child" '.[$child].vars?' <<< "$inventory_json"
}

group_vars_should_contain() {
  local child="$1"
  local var="$2"

  if get_vars_defined_at_group_vars "$child" |
     jq -e --arg var "$var" 'type=="object" and has($var)' >/dev/null
  then
    return 0
  else
    return 1
  fi
}

group_vars_should_not_contain() {
  local child="$1"
  local var="$2"

  if get_vars_defined_at_group_vars "$child" |
     jq -e --arg var "$var" 'type=="object" and has($var)' >/dev/null
  then
    return 1
  else
    return 0
  fi
}

while IFS="|" read -r level var; do

  children_group_vars=$(get_children_group_vars "$level")

  while IFS= read -r child; do
    if ! group_vars_should_contain "$child" "$var"; then
      echo "❌ $child is missing variable '$var'"
      exit 1
    fi
  done <<< "$children_group_vars"

  # Get unexpected group vars
  unexpected_group_vars=$(get_unexpected_group_vars "$children_group_vars")

  while IFS= read -r child; do
    if ! group_vars_should_not_contain "$child" "$var"; then
      echo "❌ $child has variable '$var'"
      exit 1
    fi
  done <<< "$unexpected_group_vars"

done < <(
  # yq extracts level|var pairs from cartography YAML
  yq -r '
    to_entries[]
    | .key as $k
    | .value[]
    | "\($k)|\(.)"
  ' "$cartography_file"
)

