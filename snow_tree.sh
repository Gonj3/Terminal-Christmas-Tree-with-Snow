#!/usr/bin/env bash

# Snow + centered Christmas tree with flashing lights
trap 'tput cnorm; printf "\033[0m\033[%s;1H" "$LINES"; exit' INT TERM EXIT

LINES=$(tput lines)
COLUMNS=$(tput cols)
tput civis

declare -A snowflakes
declare -A lastflakes

# Snowflake characters
flakes=($'\u2744' $'\u2745' $'\u2746')

# Tree design (each string is one row of the tree, without leading spaces)
tree_rows=(
"    /\    "
"   /  \   "
"  /++++\  "
" /+####+\ "
"/+#****+#\"
"   |||    "
)

# Calculate tree dimensions and position
tree_height=${#tree_rows[@]}
tree_width=0
for r in "${tree_rows[@]}"; do
  (( ${#r} > tree_width )) && tree_width=${#r}
done

tree_start_row=$(( (LINES / 2) - (tree_height / 2) ))
[ "$tree_start_row" -lt 1 ] && tree_start_row=1
tree_start_col=$(( (COLUMNS / 2) - (tree_width / 2) + 1 ))
[ "$tree_start_col" -lt 1 ] && tree_start_col=1

# Precompute positions inside tree that count as "lights"
# We'll mark lights where characters are one of: + * #
lights=()
for ((ri=0; ri<tree_height; ri++)); do
  row="${tree_rows[$ri]}"
  for ((ci=0; ci<${#row}; ci++)); do
    ch="${row:$ci:1}"
    case "$ch" in
      '+'|'*'|'#')
        # store as "row:col_offset" (1-based offsets inside row)
        lights+=("$ri:$ci")
        ;;
    esac
  done
done

# Color codes
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

# Function to draw tree (with flashing lights)
draw_tree() {
  local tick=$1
  for ((ri=0; ri<tree_height; ri++)); do
    row="${tree_rows[$ri]}"
    printf "\033[%s;%sH" $((tree_start_row + ri)) "$tree_start_col"
    # We'll build the row character-by-character so we can color lights
    for ((ci=0; ci<${#row}; ci++)); do
      ch="${row:$ci:1}"
      # default char output (may get overridden for lights)
      out="$ch"
      if [[ "$ch" == "+" || "$ch" == "*" || "$ch" == "#" ]]; then
        # choose if this light is on or off based on tick and randomness
        # create a deterministic-ish flicker: use (ri+ci+tick) mod something
        rnd=$(( (ri + ci + tick + (RANDOM % 3)) % 4 ))
        if [ "$rnd" -eq 0 ]; then
          color="$RED"
        elif [ "$rnd" -eq 1 ]; then
          color="$YELLOW"
        elif [ "$rnd" -eq 2 ]; then
          color="$CYAN"
        else
          color="$GREEN"
        fi
        # sometimes "off" (print a darker dot)
        off=$(( (ri + ci + tick) % 5 ))
        if [ "$off" -eq 0 ]; then
          out="${BOLD}${color}o${RESET}"
        elif [ "$off" -eq 1 ]; then
          out="${color}o${RESET}"
        else
          out="$ch"
        fi
      fi
      # print single char (no newline)
      printf "%s" "$out"
    done
    printf "%s" ""   # ensure buffer flush
  done
}

# Erase a previous flake position safely
erase_at() {
  local r=$1
  local c=$2
  [ -z "$r" ] && return
  [ "$r" -lt 1 ] && return
  [ "$r" -gt "$LINES" ] && return
  [ -z "$c" ] && return
  printf "\033[%s;%sH " "$r" "$c"
}

move_flake() {
  local col="$1"

  if [ -z "${snowflakes[$col]}" ] || [ "${snowflakes[$col]}" -ge "$LINES" ]; then
    snowflakes[$col]=1
  else
    if [ -n "${lastflakes[$col]}" ]; then
      erase_at "${lastflakes[$col]}" "$col"
    fi
  fi

  # pick a random flake char
  fchar="${flakes[$RANDOM % ${#flakes[@]}]}"

  # Avoid overwriting the tree: if current draw position is inside the tree area, skip drawing snow there
  local r="${snowflakes[$col]}"
  if [ "$r" -ge "$tree_start_row" ] && [ "$r" -lt $((tree_start_row + tree_height)) ] && \
     [ "$col" -ge "$tree_start_col" ] && [ "$col" -lt $((tree_start_col + tree_width)) ]; then
    # do nothing (flake passes behind the tree)
    :
  else
    printf "\033[%s;%sH%s" "$r" "$col" "$fchar"
  fi

  lastflakes[$col]="${snowflakes[$col]}"
  snowflakes[$col]=$(( snowflakes[$col] + 1 ))
}

# Main loop
tick=0
clear
while :; do
  # Recompute in case terminal resized
  newLINES=$(tput lines)
  newCOLUMNS=$(tput cols)
  if [ "$newLINES" -ne "$LINES" ] || [ "$newCOLUMNS" -ne "$COLUMNS" ]; then
    LINES=$newLINES
    COLUMNS=$newCOLUMNS
    tree_start_row=$(( (LINES / 2) - (tree_height / 2) ))
    [ "$tree_start_row" -lt 1 ] && tree_start_row=1
    tree_start_col=$(( (COLUMNS / 2) - (tree_width / 2) + 1 ))
    [ "$tree_start_col" -lt 1 ] && tree_start_col=1
    clear
  fi

  # Draw tree with current tick (controls light flashing)
  draw_tree "$tick"

  # spawn a new random snowflake column
  col=$(( (RANDOM % COLUMNS) + 1 ))
  move_flake "$col"

  # update existing flakes
  for x in "${!lastflakes[@]}"; do
    move_flake "$x"
  done

  tick=$((tick + 1))
  sleep 0.12
done
