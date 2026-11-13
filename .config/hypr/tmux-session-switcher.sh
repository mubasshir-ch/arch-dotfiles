#!/usr/bin/env bash
set -euo pipefail

HELPER="${HOME}/.config/hypr/tmux-lazy-helper.sh"

FILTER_ALL_ACTION="󰈲  Filter: Show All Sessions"
FILTER_LOADED_ACTION="󰈲  Filter: Loaded Only"
FILTER_UNLOADED_ACTION="󰈲  Filter: Unloaded Only"
UNLOAD_MENU_ACTION="⏸️  Unload a Loaded Session"
BACK_ACTION="⬅️  Back to Sessions"

mode="all"
case "${1:-}" in
    --loaded)
        mode="loaded"
        ;;
    --unloaded)
        mode="unloaded"
        ;;
    --unload)
        mode="unload"
        ;;
esac

while true; do
    mapfile -t loaded_sessions < <(tmux list-sessions -F "#{session_name}" 2>/dev/null | sort -u || true)
    mapfile -t saved_sessions < <("$HELPER" list-saved 2>/dev/null || true)

    unset is_loaded
    declare -A is_loaded=()
    for s in "${loaded_sessions[@]}"; do
        [ -n "$s" ] && is_loaded["$s"]=1
    done

    entries=()
    if [ "$mode" = "unload" ]; then
        prompt="Select session to unload (save & pause)"
        for s in "${loaded_sessions[@]}"; do
            [ -n "$s" ] && entries+=("⏸️  Unload: ${s}   [loaded]")
        done
        entries+=("$BACK_ACTION")
    else
        if [ "$mode" = "all" ] || [ "$mode" = "loaded" ]; then
            for s in "${loaded_sessions[@]}"; do
                [ -n "$s" ] && entries+=("🟢  ${s}   [loaded]")
            done
        fi

        if [ "$mode" = "all" ] || [ "$mode" = "unloaded" ]; then
            for s in "${saved_sessions[@]}"; do
                if [ -n "$s" ] && [ -z "${is_loaded[$s]:-}" ]; then
                    entries+=("💤  ${s}   [unloaded]")
                fi
            done
        fi

        if [ "$mode" = "all" ]; then
            prompt="Select tmux session"
            entries+=("$FILTER_LOADED_ACTION" "$FILTER_UNLOADED_ACTION")
            if [ "${#loaded_sessions[@]}" -gt 0 ]; then
                entries+=("$UNLOAD_MENU_ACTION")
            fi
        elif [ "$mode" = "loaded" ]; then
            prompt="Tmux sessions (Loaded)"
            entries+=("$FILTER_ALL_ACTION" "$FILTER_UNLOADED_ACTION")
            if [ "${#loaded_sessions[@]}" -gt 0 ]; then
                entries+=("$UNLOAD_MENU_ACTION")
            fi
        else
            prompt="Tmux sessions (Unloaded)"
            entries+=("$FILTER_ALL_ACTION" "$FILTER_LOADED_ACTION")
        fi
    fi

    selection="$(printf '%s\n' "${entries[@]}" | wofi --dmenu --columns 1 -i -p "$prompt" || true)"
    [ -z "$selection" ] && exit 0

    case "$selection" in
        "$FILTER_ALL_ACTION"|"$BACK_ACTION")
            mode="all"
            continue
            ;;
        "$FILTER_LOADED_ACTION")
            mode="loaded"
            continue
            ;;
        "$FILTER_UNLOADED_ACTION")
            mode="unloaded"
            continue
            ;;
        "$UNLOAD_MENU_ACTION")
            mode="unload"
            continue
            ;;
    esac

    if [ "$mode" = "unload" ]; then
        session="$selection"
        session="${session#⏸️  Unload: }"
        session="${session%   \[loaded\]}"
        [ -n "$session" ] && "$HELPER" unload-session "$session"
        mode="all"
        continue
    fi

    # Strip leading status icon + spaces and trailing [loaded]/[unloaded] badge
    session="$selection"
    session="${session#🟢  }"
    session="${session#💤  }"
    session="${session%   \[loaded\]}"
    session="${session%   \[unloaded\]}"

    [ -z "$session" ] && exit 0

    if ! tmux has-session -t "=${session}" 2>/dev/null; then
        "$HELPER" restore-session "$session"
    fi

    exec kitty -e tmux attach -t "=${session}"
done
