#!/bin/zsh
# Claude Code statusLine script
# Inspired by Oh My Zsh robbyrussell theme + Nerd Font icons

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
mode=$(echo "$input" | jq -r '.output_style.name // "default"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_id=$(echo "$input" | jq -r '.session_id // "default"')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')

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
    model_short=$(echo "$model" | sed 's/ *(.*//')
    model_part=" \033[1;35m󰚩 ${model_short}\033[0m"
fi

# Mode part
mode_part=""
if [ "$mode" = "plan" ]; then
    mode_part=" \033[1;36m[Plan]\033[0m"
elif [ "$mode" = "fast" ]; then
    mode_part=" \033[1;33m[Fast]\033[0m"
fi

# Session duration
duration_part=""
if [ -n "$duration_ms" ] && [ "$duration_ms" != "null" ]; then
    total_sec=$(( duration_ms / 1000 ))
    hours=$(( total_sec / 3600 ))
    mins=$(( (total_sec % 3600) / 60 ))
    if [ "$hours" -gt 0 ]; then
        duration_part=" \033[0;36m${hours}h${mins}m\033[0m"
    else
        duration_part=" \033[0;36m${mins}m\033[0m"
    fi
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
            delta_str="(↑ ${delta})"
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

# Rate limit (5h/7d) via Anthropic OAuth API, cached 5 min
rate_part=""
cache_file="/tmp/claude_statusline_usage_cache.json"
cache_ttl=300
need_refresh=true
if [ -f "$cache_file" ]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
    [ "$cache_age" -lt "$cache_ttl" ] && need_refresh=false
fi
if $need_refresh; then
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [ -n "$token" ]; then
        resp=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.72" 2>/dev/null)
        if echo "$resp" | jq -e '.five_hour' > /dev/null 2>&1; then
            echo "$resp" > "$cache_file"
        fi
    fi
fi
if [ -f "$cache_file" ]; then
    cache_data=$(cat "$cache_file")
    h5=$(echo "$cache_data" | jq -r '.five_hour.utilization // empty')
    d7=$(echo "$cache_data" | jq -r '.seven_day.utilization // empty')
    h5_reset=$(echo "$cache_data" | jq -r '.five_hour.resets_at // empty')
    d7_reset=$(echo "$cache_data" | jq -r '.seven_day.resets_at // empty')
    if [ -n "$h5" ] && [ -n "$d7" ]; then
        h5_int=$(printf "%.0f" "$h5")
        d7_int=$(printf "%.0f" "$d7")
        # Format reset times: 5h show HH:MM, 7d show M/D HH:MM
        h5_reset_fmt=""
        d7_reset_fmt=""
        if [ -n "$h5_reset" ] && [ "$h5_reset" != "null" ]; then
            h5_reset_fmt=$(python3 -c "from datetime import datetime,timezone,timedelta;dt=datetime.fromisoformat('$h5_reset').astimezone(timezone(timedelta(hours=8)));print(dt.strftime('%H:%M'))" 2>/dev/null)
        fi
        if [ -n "$d7_reset" ] && [ "$d7_reset" != "null" ]; then
            d7_reset_fmt=$(python3 -c "from datetime import datetime,timezone,timedelta;dt=datetime.fromisoformat('$d7_reset').astimezone(timezone(timedelta(hours=8)));print(dt.strftime('%-m/%-d %H:%M'))" 2>/dev/null)
        fi
        # Color by utilization
        for v in h5 d7; do
            val=$(eval echo \$${v}_int)
            if [ "$val" -lt 50 ]; then eval "${v}_c=\"\033[0;32m\""
            elif [ "$val" -lt 70 ]; then eval "${v}_c=\"\033[0;33m\""
            elif [ "$val" -lt 90 ]; then eval "${v}_c=\"\033[38;5;208m\""
            else eval "${v}_c=\"\033[0;31m\""; fi
        done
        rate_part=" ${h5_c}5h:${h5_int}%${h5_reset_fmt:+@${h5_reset_fmt}}\033[0m ${d7_c}7d:${d7_int}%${d7_reset_fmt:+@${d7_reset_fmt}}\033[0m"
    fi
fi

# Output: line 1 = project info + mode, line 2 = cost + rate limit
printf "\033[1;32m➜\033[0m \033[0;36m %s\033[0m%b%b%b%b%b" \
    "$dir_name" "$git_branch" "$ctx_part" "$model_part" "$mode_part" "$duration_part"
line2=""
[ -n "$cost_part" ] && line2="${cost_part}"
[ -n "$rate_part" ] && line2="${line2}${rate_part}"
if [ -n "$line2" ]; then
    printf "\n%b" "$line2"
fi
