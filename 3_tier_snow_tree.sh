#!/usr/bin/env bash
trap 'tput cnorm; printf "\033[0m\033[%s;1H" "$LINES"; exit' INT TERM EXIT

tput civis
LINES=$(tput lines)
COLUMNS=$(tput cols)
declare -A snowflakes
declare -A lastflakes

flakes=($'\u2744' $'\u2745' $'\u2746')

GREEN=$'\033[32m'
BROWN=$'\033[38;5;94m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

# ---------------------------
# THREE-TIER TREE DEFINITION
# ---------------------------
tree_rows=(
"                     *                     "  # pulsing star
"                    +#*                    "
"                   +###*+                  "
"                  +#####*#+                "
"                 +#######*#+               "
"               " # top tier

"                  +#########+               "
"                 +###########*+             "
"                +#############*#+           "
"               +###############*#+          "
"             " # middle tier

"                +#################+          "
"               +###################*+       "
"              +#####################*#+     "
"             +#######################*#+    "
"            +#########################*#+   "
"           +###########################*#+  "
"          +#############################*#+ " # bottom tier
"                    |||||                 "
"                    |||||                 "
)

tree_height=${#tree_rows[@]}
tree_width=0
for row in "${tree_rows[@]}"; do
  (( ${#row} > tree_width )) && tree_width=${#row}
done

tree_start_row=$(( (LINES / 2) - (tree_height / 2) ))
[ "$tree_start_row" -lt 1 ] && tree_start_row=1
tree_start_col=$(( (COLUMNS / 2) - (tree_width / 2) + 1 ))
[ "$tree_start_col" -lt 1 ] && tree_start_col=1

# ---------------------------
draw_tree() {
  local tick=$1
  for ((ri=0; ri<tree_height; ri++)); do
    row="${tree_rows[$ri]}"
    printf "\033[%s;%sH" $((tree_start_row + ri)) "$tree_start_col"
    for ((ci=0; ci<${#row}; ci++)); do
      ch="${row:$ci:1}"
      out="$ch"
      # pulsing star
      if [ "$ri" -eq 0 ] && [ "$ch" == "*" ]; then
        rnd=$(( (tick % 6) + 1 ))
        case $rnd in
          1) color=$RED ;;
          2) color=$YELLOW ;;
          3) color=$CYAN ;;
          4) color=$GREEN ;;
          5) color=$RED ;;
          6) color=$YELLOW ;;
        esac
        out="${BOLD}${color}*\033[0m"
      # flashing lights + # *
      elif [[ "$ch" == "+" || "$ch" == "#" || "$ch" == "*" ]]; then
        rnd=$(( (ri+ci+tick+RANDOM%4) % 4 ))
        case $rnd in
          0) color=$RED ;;
          1) color=$YELLOW ;;
          2) color=$CYAN ;;
          3) color=$GREEN ;;
        esac
        off=$(( (ri+ci+tick) % 6 ))
        if [ "$off" -le 1 ]; then
          out="${BOLD}${color}o${RESET}"
        else
          out="${GREEN}${ch}${RESET}"
        fi
      # / \ outlines
      elif [[ "$ch" == "/" || "$ch" == "\\" ]]; then
        out="${GREEN}${ch}${RESET}"
      # trunk
      elif [[ "$ch" == "|" ]]; then
        out="${BROWN}${ch}${RESET}"
      fi
      printf "%s" "$out"
    done
  done
}

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
  fchar="${flakes[$RANDOM % ${#flakes[@]}]}"
  local r="${snowflakes[$col]}"
  # skip snow behind tree
  if [ "$r" -ge "$tree_start_row" ] && [ "$r" -lt $((tree_start_row + tree_height)) ] && \
     [ "$col" -ge "$tree_start_col" ] && [ "$col" -lt $((tree_start_col + tree_width)) ]; then
    :
  else
    printf "\033[%s;%sH%s" "$r" "$col" "$fchar"
  fi
  lastflakes[$col]="$r"
  snowflakes[$col]=$(( r + 1 ))
}

# ---------------------------
clear
tick=0
while :; do
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
  draw_tree "$tick"
  col=$(( (RANDOM % COLUMNS) + 1 ))
  move_flake "$col"
  for x in "${!lastflakes[@]}"; do
    move_flake "$x"
  done
  tick=$((tick + 1))
  sleep 0.12
done
