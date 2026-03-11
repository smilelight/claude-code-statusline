#!/bin/zsh
# Claude Code statusLine script
# Inspired by Oh My Zsh robbyrussell theme + Nerd Font icons

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_id=$(echo "$input" | jq -r '.session_id // "default"')

# Current directory basename
dir_name=$(basename "$cwd")

# Git branch info
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        dirty=""
        if ! git -C "$cwd" diff --quiet 2>/dev/null || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
            dirty=" ✗"
        fi
        git_branch=" \033[1;34m ${branch}${dirty}\033[0m"
    fi
fi

# Context usage: color tiers + mini progress bar
ctx_part=""
if [ -n "$used" ] && [ "$used" != "null" ]; then
    used_int=$(printf "%.0f" "$used")
    if [ "$used_int" -le 20 ]; then
        ctx_color="\033[0;32m"       # green
        pie="○"
    elif [ "$used_int" -le 40 ]; then
        ctx_color="\033[0;36m"       # cyan
        pie="◔"
    elif [ "$used_int" -le 60 ]; then
        ctx_color="\033[0;33m"       # yellow
        pie="◑"
    elif [ "$used_int" -le 80 ]; then
        ctx_color="\033[38;5;208m"   # orange
        pie="◕"
    else
        ctx_color="\033[0;31m"       # red
        pie="●"
    fi

    ctx_part=" ${ctx_color}${pie} ${used_int}%\033[0m"
fi

# Model part with robot icon
model_part=""
if [ -n "$model" ] && [ "$model" != "null" ]; then
    model_part=" \033[1;35m󰚩 ${model}\033[0m"
fi

# Cost part with delta tracking
cost_part=""
if [ -n "$cost" ] && [ "$cost" != "null" ] && [ "$cost" != "0" ]; then
    cost_fmt=$(printf "%.2f" "$cost")
    # Calculate delta from last refresh
    cost_file="/tmp/claude_statusline_cost_${session_id}"
    delta_str=""
    if [ -f "$cost_file" ]; then
        prev_cost=$(cat "$cost_file")
        delta=$(printf "%.2f" "$(echo "$cost - $prev_cost" | bc 2>/dev/null)")
        if [ "$delta" != "0.00" ] && [ "$delta" != "0" ]; then
            delta_str="(⬆︎${delta})"
        fi
    fi
    echo "$cost" > "$cost_file"

    # Daily cost tracking: record baseline on first seen today, sum increments
    today=$(date +%Y-%m-%d)
    daily_dir="/tmp/claude_daily_costs"
    mkdir -p "$daily_dir"
    baseline_file="${daily_dir}/${today}_baseline_${session_id}"
    if [ ! -f "$baseline_file" ]; then
        echo "$cost" > "$baseline_file"
    fi
    baseline=$(cat "$baseline_file")
    session_today=$(printf "%.2f" "$(echo "$cost - $baseline" | bc 2>/dev/null)")
    # Write this session's daily increment for summing
    echo "$session_today" > "${daily_dir}/${today}_incr_${session_id}"
    daily_total=$(cat "${daily_dir}/${today}_incr_"* 2>/dev/null | paste -sd+ - | bc 2>/dev/null)
    daily_fmt=$(printf "%.2f" "${daily_total:-0}")

    day_num=$(date +%-d)
    cost_part=" \033[0;33m💰${cost_fmt}${delta_str} [${day_num}日 💰${daily_fmt}]\033[0m"
fi

# Memory usage
mem_pct=$(vm_stat | awk -v ps=$(sysctl -n vm.pagesize) -v total=$(sysctl -n hw.memsize) '
/Pages active/ {a=$3+0} /Pages wired/ {w=$4+0} /Pages compressed/ {c=$3+0}
END { printf "%.0f", (a+w+c)*ps/total*100 }')
if [ "$mem_pct" -le 50 ]; then
    mem_color="\033[0;32m"
elif [ "$mem_pct" -le 75 ]; then
    mem_color="\033[0;33m"
else
    mem_color="\033[0;31m"
fi
mem_part=" ${mem_color}MEM ${mem_pct}%\033[0m"

# Output
printf "\033[1;32m➜\033[0m \033[0;36m %s\033[0m%b%b%b%b%b" \
    "$dir_name" "$git_branch" "$ctx_part" "$model_part" "$cost_part" "$mem_part"
