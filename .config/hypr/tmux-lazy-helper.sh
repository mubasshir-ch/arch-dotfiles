#!/usr/bin/env bash
set -euo pipefail

RESURRECT_SCRIPTS_DIR="${HOME}/.tmux/plugins/tmux-resurrect/scripts"

expand_path() {
    local p="$1"
    local host
    host="$(hostname 2>/dev/null || uname -n 2>/dev/null || true)"
    p="${p//\$HOME/$HOME}"
    p="${p//\$HOSTNAME/$host}"
    p="${p/#\~/$HOME}"
    printf '%s\n' "$p"
}

get_resurrect_dir() {
    local opt_dir=""
    opt_dir="$(tmux show-option -gqv @resurrect-dir 2>/dev/null || true)"
    if [ -n "$opt_dir" ]; then
        expand_path "$opt_dir"
        return 0
    fi
    if [ -d "${HOME}/.tmux/resurrect" ]; then
        printf '%s\n' "${HOME}/.tmux/resurrect"
    else
        printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
    fi
}

get_last_file() {
    printf '%s/last\n' "$(get_resurrect_dir)"
}

mark_loaded() {
    local session_name="${1:-}"
    [ -z "$session_name" ] && return 0

    local current=""
    current="$(tmux show-option -gqv @lazy_loaded_sessions 2>/dev/null || true)"
    if [[ ":${current}:" != *":${session_name}:"* ]]; then
        tmux set-option -gq @lazy_loaded_sessions "${current}:${session_name}:" 2>/dev/null || true
    fi
}

unmark_loaded() {
    local session_name="${1:-}"
    [ -z "$session_name" ] && return 0

    local current=""
    current="$(tmux show-option -gqv @lazy_loaded_sessions 2>/dev/null || true)"
    local updated="${current//:${session_name}:/}"
    tmux set-option -gq @lazy_loaded_sessions "$updated" 2>/dev/null || true
}

ensure_tmux_config() {
    if [ -z "$(tmux show-option -gqv @resurrect-processes 2>/dev/null || true)" ]; then
        tmux source-file "${HOME}/.tmux.conf" >/dev/null 2>&1 || true
        tmux set-option -gq @resurrect-processes ':all:' 2>/dev/null || true
        tmux set-option -gq @resurrect-capture-pane-contents 'on' 2>/dev/null || true
    fi
}

unload_session() {
    local target_session="${1:-}"
    if [ -z "$target_session" ]; then
        target_session="$(tmux display-message -p "#{session_name}" 2>/dev/null || true)"
    fi
    [ -z "$target_session" ] && return 1

    if ! tmux has-session -t "=${target_session}" 2>/dev/null; then
        unmark_loaded "$target_session"
        return 0
    fi

    ensure_tmux_config

    if [ -x "$RESURRECT_SCRIPTS_DIR/save.sh" ]; then
        "$RESURRECT_SCRIPTS_DIR/save.sh" quiet
    fi

    unmark_loaded "$target_session"
    tmux kill-session -t "=${target_session}"
}

list_saved() {
    local last_file
    last_file="$(get_last_file)"
    if [ ! -f "$last_file" ]; then
        return 0
    fi
    awk -F'\t' '/^(pane|window|grouped_session)\t/ && $2 != "" { print $2 }' "$last_file" | sort -u
}

session_in_file() {
    local target="$1"
    local file="$2"
    awk -F'\t' -v target="$target" '
        /^(pane|window|grouped_session)\t/ && $2 == target { found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "$file"
}

# Compatibility stubs for tmux-resurrect's process_restore_helpers.sh
pane_exists() {
    local session_name="$1"
    local window_number="$2"
    local pane_index="$3"
    tmux list-panes -t "=${session_name}:${window_number}" -F "#{pane_index}" 2>/dev/null |
        grep -qx "$pane_index"
}

is_pane_registered_as_existing() {
    return 1
}

normalize_dir() {
    local dir="$1"
    dir="${dir#:}"
    dir="${dir//\\ / }"
    dir="${dir/#\~/$HOME}"
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        dir="$HOME"
    fi
    printf '%s\n' "$dir"
}

restore_session() {
    local target_session="${1:-}"
    [ -z "$target_session" ] && return 1

    if tmux has-session -t "=${target_session}" 2>/dev/null; then
        mark_loaded "$target_session"
        return 0
    fi

    local last_file
    last_file="$(get_last_file)"
    if [ ! -f "$last_file" ] || ! session_in_file "$target_session" "$last_file"; then
        tmux new-session -d -s "$target_session"
        mark_loaded "$target_session"
        return 0
    fi

    # Check if target_session is a grouped session
    local grouped_line=""
    grouped_line="$(awk -F'\t' -v target="$target_session" '
        $1 == "grouped_session" && $2 == target { print $0; exit }
    ' "$last_file")"

    if [ -n "$grouped_line" ]; then
        local _lt _gs original_session alternate_window active_window
        IFS=$'\t' read -r _lt _gs original_session alternate_window active_window <<< "$grouped_line"
        if [ -n "$original_session" ] && [ "$original_session" != "$target_session" ]; then
            restore_session "$original_session"
            TMUX="" tmux new-session -d -s "$target_session" -t "$original_session"
            alternate_window="${alternate_window#:}"
            active_window="${active_window#:}"
            if [ -n "$alternate_window" ]; then
                tmux select-window -t "=${target_session}:${alternate_window}" 2>/dev/null || true
            fi
            if [ -n "$active_window" ]; then
                tmux select-window -t "=${target_session}:${active_window}" 2>/dev/null || true
            fi
            mark_loaded "$target_session"
            return 0
        fi
    fi

    # 1. Restore panes for target_session
    local pane_contents_restored="false"
    local archive_file=""
    archive_file="$(get_resurrect_dir)/pane_contents.tar.gz"
    local restore_dir=""
    restore_dir="$(get_resurrect_dir)/restore"
    local restore_contents_dir="${restore_dir}/pane_contents"

    if [ -f "$archive_file" ]; then
        rm -rf "$restore_contents_dir" 2>/dev/null || true
        mkdir -p "$restore_dir"
        if tar xzf "$archive_file" -C "$restore_dir" 2>/dev/null; then
            pane_contents_restored="true"
        fi
    fi

    local pane_rows
    pane_rows="$(awk -F'\t' -v target="$target_session" '
        $1 == "pane" && $2 == target {
            # Prefix potentially-empty fields with ":" so bash IFS=tab read never collapses adjacent tabs
            print $3 "\t" ":" $5 "\t" $6 "\t" ":" $7 "\t" $8 "\t" $9 "\t" $11
        }
    ' "$last_file")"

    local default_shell="${SHELL:-/bin/zsh}"
    while IFS=$'\t' read -r window_number window_flags pane_index pane_title dir pane_active pane_full_command; do
        [ -z "$window_number" ] && continue
        window_flags="${window_flags#:}"
        pane_title="${pane_title#:}"
        dir="$(normalize_dir "$dir")"
        local pane_cmd_clean="${pane_full_command#:}"

        local content_file="${restore_contents_dir}/pane-${target_session}:${window_number}.${pane_index}"
        local pane_cmd=""
        if [ -z "$pane_cmd_clean" ] && [ "$pane_contents_restored" = "true" ] && [ -s "$content_file" ]; then
            local quoted_cf
            printf -v quoted_cf '%q' "$content_file"
            local live_shell
            live_shell="$(tmux show-option -gqv default-shell 2>/dev/null || true)"
            [ -n "$live_shell" ] && default_shell="$live_shell"
            pane_cmd="cat ${quoted_cf} 2>/dev/null; exec ${default_shell} -l"
        fi

        if ! tmux has-session -t "=${target_session}" 2>/dev/null; then
            if [ -n "$pane_cmd" ]; then
                TMUX="" tmux new-session -d -s "$target_session" -c "$dir" "$pane_cmd"
            else
                TMUX="" tmux new-session -d -s "$target_session" -c "$dir"
            fi
            local created_window_num
            created_window_num="$(tmux list-windows -t "=${target_session}" -F "#{window_index}" | head -n1)"
            if [ -n "$created_window_num" ] && [ "$created_window_num" != "$window_number" ]; then
                tmux move-window -s "=${target_session}:${created_window_num}" -t "=${target_session}:${window_number}"
            fi
        elif ! tmux list-windows -t "=${target_session}" -F "#{window_index}" 2>/dev/null | grep -qx "$window_number"; then
            if [ -n "$pane_cmd" ]; then
                tmux new-window -d -t "=${target_session}:${window_number}" -c "$dir" "$pane_cmd"
            else
                tmux new-window -d -t "=${target_session}:${window_number}" -c "$dir"
            fi
        elif ! pane_exists "$target_session" "$window_number" "$pane_index"; then
            if [ -n "$pane_cmd" ]; then
                tmux split-window -d -t "=${target_session}:${window_number}" -c "$dir" "$pane_cmd"
            else
                tmux split-window -d -t "=${target_session}:${window_number}" -c "$dir"
            fi
            tmux resize-pane -t "=${target_session}:${window_number}" -U 999 2>/dev/null || true
        fi

        if [ -n "$pane_title" ]; then
            tmux select-pane -t "=${target_session}:${window_number}.${pane_index}" -T "$pane_title" 2>/dev/null || true
        fi
    done <<< "$pane_rows"

    ensure_tmux_config

    if [ -f "$RESURRECT_SCRIPTS_DIR/variables.sh" ] && [ -f "$RESURRECT_SCRIPTS_DIR/helpers.sh" ]; then
        CURRENT_DIR="$RESURRECT_SCRIPTS_DIR"
        # shellcheck disable=SC1091
        source "$RESURRECT_SCRIPTS_DIR/variables.sh"
        # shellcheck disable=SC1091
        source "$RESURRECT_SCRIPTS_DIR/helpers.sh"
        # shellcheck disable=SC1091
        source "$RESURRECT_SCRIPTS_DIR/process_restore_helpers.sh"
    fi

    # 2. Restore window layouts & properties for target_session
    local window_rows
    window_rows="$(awk -F'\t' -v target="$target_session" '
        $1 == "window" && $2 == target {
            print $3 "\t" $4 "\t" ":" $6 "\t" ":" $7 "\t" ":" $8
        }
    ' "$last_file")"

    while IFS=$'\t' read -r window_number window_name window_flags window_layout automatic_rename; do
        [ -z "$window_number" ] && continue
        window_name="${window_name#:}"
        window_flags="${window_flags#:}"
        window_layout="${window_layout#:}"
        automatic_rename="${automatic_rename#:}"

        if [ -n "$window_layout" ]; then
            tmux select-layout -t "=${target_session}:${window_number}" "$window_layout" 2>/dev/null || true
        fi
        if [ -n "$window_name" ]; then
            tmux rename-window -t "=${target_session}:${window_number}" "$window_name" 2>/dev/null || true
        fi
        if [ "$automatic_rename" = ":" ] || [ -z "$automatic_rename" ]; then
            tmux set-window-option -u -t "=${target_session}:${window_number}" automatic-rename 2>/dev/null || true
        else
            tmux set-window-option -t "=${target_session}:${window_number}" automatic-rename "$automatic_rename" 2>/dev/null || true
        fi
    done <<< "$window_rows"

    # 3. Restore pane processes for target_session (without calling switch-client)
    if declare -F restore_pane_processes_enabled >/dev/null 2>&1 && restore_pane_processes_enabled; then
        while IFS=$'\t' read -r window_number window_flags pane_index pane_title dir pane_active pane_full_command; do
            [ -z "$window_number" ] && continue
            pane_full_command="${pane_full_command#:}"
            [ -z "$pane_full_command" ] && continue
            dir="$(normalize_dir "$dir")"

            if _process_should_be_restored "$pane_full_command" "$target_session" "$window_number" "$pane_index"; then
                local command=""
                local inline_strategy=""
                inline_strategy="$(_get_inline_strategy "$pane_full_command")"
                if [ -n "$inline_strategy" ]; then
                    if _strategy_exists "$inline_strategy"; then
                        local strategy_file
                        strategy_file="$(_get_strategy_file "$inline_strategy")"
                        inline_strategy="$("$strategy_file" "$pane_full_command" "$dir")"
                    fi
                    command="$inline_strategy"
                elif _strategy_exists "$pane_full_command"; then
                    local strategy_file
                    strategy_file="$(_get_strategy_file "$pane_full_command")"
                    command="$("$strategy_file" "$pane_full_command" "$dir")"
                else
                    command="$pane_full_command"
                fi
                if [[ "$command" == "agy" ]]; then
                    command="agy --continue"
                elif [[ "$command" == "nvim" || "$command" == "nvim "* ]]; then
                    if [ -e "${dir}/Session.vim" ]; then
                        command="nvim -S"
                    else
                        command="nvim"
                    fi
                fi
                tmux send-keys -t "=${target_session}:${window_number}.${pane_index}" "$command" "C-m"
            fi
        done <<< "$pane_rows"
    fi

    # 4. Restore active panes and zoomed windows (without switch-client)
    while IFS=$'\t' read -r window_number window_flags pane_index pane_title dir pane_active pane_full_command; do
        [ -z "$window_number" ] && continue
        window_flags="${window_flags#:}"
        if [ "$pane_active" = "1" ]; then
            tmux select-pane -t "=${target_session}:${window_number}.${pane_index}" 2>/dev/null || true
            if [[ "$window_flags" == *Z* ]]; then
                tmux resize-pane -t "=${target_session}:${window_number}.${pane_index}" -Z 2>/dev/null || true
            fi
        fi
    done <<< "$pane_rows"

    # 5. Restore alternate (-) then active (*) window for target_session
    while IFS=$'\t' read -r window_number window_name window_flags window_layout automatic_rename; do
        [ -z "$window_number" ] && continue
        window_flags="${window_flags#:}"
        if [[ "$window_flags" == *-* ]]; then
            tmux select-window -t "=${target_session}:${window_number}" 2>/dev/null || true
        fi
    done <<< "$window_rows"

    while IFS=$'\t' read -r window_number window_name window_flags window_layout automatic_rename; do
        [ -z "$window_number" ] && continue
        window_flags="${window_flags#:}"
        if [[ "$window_flags" == *\** ]]; then
            tmux select-window -t "=${target_session}:${window_number}" 2>/dev/null || true
        fi
    done <<< "$window_rows"

    mark_loaded "$target_session"
}

post_save_hook() {
    local new_file="${1:-}"
    local last_file
    last_file="$(get_last_file)"

    if [ -z "$new_file" ] || [ ! -f "$new_file" ] || [ ! -f "$last_file" ]; then
        return 0
    fi

    # Ensure all currently running sessions are recorded as loaded
    local running_session
    while IFS= read -r running_session; do
        [ -n "$running_session" ] && mark_loaded "$running_session"
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

    local loaded_list
    loaded_list="$(tmux show-option -gqv @lazy_loaded_sessions 2>/dev/null || true)"

    local tmp_file
    tmp_file="$(mktemp)"

    awk -F'\t' -v loaded="$loaded_list" '
        BEGIN { OFS = "\t" }
        # First pass: read new_file
        FNR == NR {
            if ($1 == "grouped_session") {
                new_grouped[++ng] = $0
                in_new[$2] = 1
            } else if ($1 == "pane") {
                new_pane[++np] = $0
                in_new[$2] = 1
            } else if ($1 == "window") {
                new_win[++nw] = $0
                in_new[$2] = 1
            } else if ($1 == "state") {
                new_state[++ns] = $0
            } else if ($0 != "") {
                new_other[++no] = $0
            }
            next
        }
        # Second pass: read last_file and keep lines for sessions that were never loaded
        {
            sess = $2
            if (sess == "" || (sess in in_new)) next
            if (index(":" loaded ":", ":" sess ":") > 0) next

            if ($1 == "grouped_session") {
                keep_grouped[++kg] = $0
                kept[sess] = 1
            } else if ($1 == "pane") {
                keep_pane[++kp] = $0
                kept[sess] = 1
            } else if ($1 == "window") {
                keep_win[++kw] = $0
                kept[sess] = 1
            }
        }
        END {
            for (i = 1; i <= ng; i++) print new_grouped[i]
            for (i = 1; i <= kg; i++) print keep_grouped[i]
            for (i = 1; i <= np; i++) print new_pane[i]
            for (i = 1; i <= kp; i++) print keep_pane[i]
            for (i = 1; i <= nw; i++) print new_win[i]
            for (i = 1; i <= kw; i++) print keep_win[i]
            for (i = 1; i <= ns; i++) print new_state[i]
            for (i = 1; i <= no; i++) print new_other[i]
        }
    ' "$new_file" "$last_file" > "$tmp_file"

    mv "$tmp_file" "$new_file"

    # Preserve pane contents of unloaded sessions when capture-pane-contents is enabled
    local capture_opt
    capture_opt="$(tmux show-option -gqv @resurrect-capture-pane-contents 2>/dev/null || true)"
    local res_dir
    res_dir="$(get_resurrect_dir)"
    local archive_file="${res_dir}/pane_contents.tar.gz"
    if [ "$capture_opt" = "on" ] && [ -f "$archive_file" ]; then
        local save_dir="${res_dir}/save"
        local save_contents_dir="${save_dir}/pane_contents"
        mkdir -p "$save_dir"
        if tar xzf "$archive_file" -C "$save_dir" 2>/dev/null && [ -d "$save_contents_dir" ]; then
            # Keep pane-* files only for unloaded sessions; running sessions will be freshly
            # dumped by save.sh, and killed sessions should not keep stale pane contents.
            local running_list=":"
            while IFS= read -r running_session; do
                [ -n "$running_session" ] && running_list="${running_list}${running_session}:"
            done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

            local pf fname sess_part
            for pf in "$save_contents_dir"/pane-*; do
                [ -e "$pf" ] || continue
                fname="${pf##*/}"
                sess_part="${fname#pane-}"
                sess_part="${sess_part%%:*}"
                if [[ "$running_list" == *":${sess_part}:"* ]] || [[ ":${loaded_list}:" == *":${sess_part}:"* ]]; then
                    rm -f "$pf"
                fi
            done
        fi
    fi
}

auto_save() {
    if ! tmux list-sessions >/dev/null 2>&1; then
        return 0
    fi
    local interval last_save now
    interval="$(tmux show-option -gqv @lazy_autosave_interval 2>/dev/null || true)"
    [[ "$interval" =~ ^[0-9]+$ ]] || interval=300
    last_save="$(tmux show-option -gqv @lazy_last_autosave 2>/dev/null || true)"
    [[ "$last_save" =~ ^[0-9]+$ ]] || last_save=0
    now="$(date +%s)"
    if (( now - last_save >= interval )); then
        tmux set-option -gq @lazy_last_autosave "$now" 2>/dev/null || true
        if [ -x "$RESURRECT_SCRIPTS_DIR/save.sh" ]; then
            nohup "$RESURRECT_SCRIPTS_DIR/save.sh" quiet >/dev/null 2>&1 &
        fi
    fi
}

cmd="${1:-}"
shift || true

case "$cmd" in
    resurrect-file)
        get_last_file
        ;;
    list-saved)
        list_saved
        ;;
    mark-loaded)
        mark_loaded "${1:-}"
        ;;
    unmark-loaded)
        unmark_loaded "${1:-}"
        ;;
    unload-session)
        unload_session "${1:-}"
        ;;
    auto-save)
        auto_save
        ;;
    restore-session)
        restore_session "${1:-}"
        ;;
    post-save-hook)
        post_save_hook "${1:-}"
        ;;
    *)
        echo "Usage: $0 {resurrect-file|list-saved|mark-loaded <session>|unmark-loaded <session>|unload-session [session]|auto-save|restore-session <session>|post-save-hook <file>}" >&2
        exit 1
        ;;
esac
