-- Source a file (multi-file configs)
-- require("myColors")
require("media-binds")
require("env_var")
require("env_var_device")

-- Setup monitors
-- See https://wiki.hyprland.org/Configuring/Monitors/
-- Fallback (if one monitor disconnected)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

--Laptop Monitor
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1.25 })

-- Left monitor — Samsung 1366x768@60Hz (vertically centered at 0x156)
hl.monitor({ output = "DP-1", mode = "1366x768@59.79", position = "0x156", scale = 1 })

-- Center monitor — LG 1920x1080@75Hz (offset by left monitor width: 1366x0)
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@74.97", position = "1366x0", scale = 1 })


-- Dual monitor example on G15 Strix
-- eDP-1 is the built in monitor while DP-1 is external
-- Both monitors here are at 1440 and 165Hz
-- DP-1 is on the left and  eDP-1 is on the right
--hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
--hl.monitor({ output = "eDP-1", mode = "2560x1440@165", position = "2560x0", scale = 1 })

-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@74.97300", position = "0x0", scale = 1 })

-- See https://wiki.hyprland.org/Configuring/Keywords/ for more

-- Execute your favorite apps at launch
hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/xdg-portal-hyprland")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment --all")
    hl.exec_cmd("hyprctl setcursor catppuccin-mocha-dark-cursors 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-lavender-standard+default'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-dark-cursors'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("swaybg -m fill -i ~/.config/hypr/wallpaper.jpg")
    hl.exec_cmd("swww init")
    -- hl.exec_cmd("mako")
    hl.exec_cmd("swaync")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("qbittorrent --no-splash &")
    hl.exec_cmd("~/.config/hypr/start-tmux-restore.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd([[bash -c 'if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then printf "auth {\n    fingerprint {\n        enabled = true\n    }\n}\n" > ~/.config/hypr/hyprlock-device.conf; rot8 & ~/.config/hypr/tablet-mode.sh & else printf "auth {\n    fingerprint {\n        enabled = false\n    }\n}\n" > ~/.config/hypr/hyprlock-device.conf; systemctl --user start openrgb-server.service openrgb-breathing-colorshift.service; fi']])
    hl.exec_cmd("~/.local/bin/sysupdate-notify --startup")
    hl.exec_cmd("~/.config/HyprV/hyprv_util setbg")
    hl.exec_cmd("lan-mouse daemon")
end)

hl.on("config.reloaded", function()
    hl.exec_cmd("~/.config/HyprV/hyprv_util setbg")
end)

-- For all categories, see https://wiki.hyprland.org/Configuring/Variables/
hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",

        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
        },

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
    },

    cursor = {
        no_hardware_cursors = true,
        enable_hyprcursor = false,
        sync_gsettings_theme = true,
    },

    general = {
        -- See https://wiki.hyprland.org/Configuring/Variables/ for more

        gaps_in = 5,
        gaps_out = 5,
        border_size = 2,
        --col = { active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 } },
        col = {
            active_border = "rgb(cdd6f4)",
            inactive_border = "rgba(595959aa)",
        },

        layout = "dwindle",
    },

    misc = {
        disable_hyprland_logo = true,
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },

    decoration = {
        -- See https://wiki.hyprland.org/Configuring/Variables/ for more

        rounding = 10,

        blur = {
            enabled = true,
            size = 7,
            passes = 4,
            new_optimizations = true,
        },
        -- blurls = lockscreen
        -- shadow = {
        --     enabled = true,
        --     range = 4,
        --     render_power = 3,
        --     color = "rgba(1a1a1aee)",
        -- },
    },
})

hl.layer_rule({ match = { namespace = "lockscreen" }, blur = true })
hl.layer_rule({ match = { namespace = "swaync-control-center" }, blur = true })
hl.layer_rule({ match = { namespace = "swaync-control-center" }, ignore_alpha = 0.5 })

hl.config({
    animations = {
        enabled = true,
    },
})

-- Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
hl.curve("myBezier", { type = "bezier", points = { { 0.10, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 7,  bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,  bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6,  bezier = "default" })

hl.config({
    dwindle = {
        -- See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        -- pseudotile = true, -- master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true, -- you probably want this
    },

    master = {
        -- See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        -- new_is_master = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

-- gestures {
--     -- See https://wiki.hyprland.org/Configuring/Variables/ for more
--     workspace_swipe = off
-- }

-- Example per-device config
-- See https://wiki.hyprland.org/Configuring/Keywords/#executing for more
-- hl.device({
--     name = "epic mouse V1",
--     sensitivity = -0.5,
-- })

-- Example windowrule v1
--windowrule = float, ^(kitty)$
--windowrule = float,^(pavucontrol)$
--windowrule = float,^(blueman-manager)$
--windowrule = float,^(nm-connection-editor)$
--windowrule = float,^(chromium)$
--windowrule = float,^(thunar)$
--windowrule = float, title:^(btop)$
--windowrule = float, title:^(update-sys)$

-- Example windowrule v2
-- windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
-- rules below would make the specific app transparent
-- windowrulev2 = opacity 0.8 0.8,class:^(kitty)$
-- windowrulev2 = animation popin,class:^(kitty)$,title:^(update-sys)$
-- windowrulev2 = animation popin,class:^(thunar)$
-- windowrulev2 = opacity 0.8 0.8,class:^(thunar)$
-- windowrulev2 = opacity 0.8 0.8,class:^(VSCodium)$
-- windowrulev2 = animation popin,class:^(chromium)$
-- windowrulev2 = move cursor -3% -105%,class:^(wofi)$
-- windowrulev2 = noanim,class:^(wofi)$
-- windowrulev2 = opacity 0.8 0.6,class:^(wofi)$
-- windowrulev2 = float,class:ibus-ui-gtk3,focus:false

-- --- Kitty ---
-- hl.window_rule({ match = { class = "^(kitty)$", title = "^(kitty)$" }, float = true })
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "0.8 0.8" })
hl.window_rule({ match = { class = "^(kitty)$", title = "^(update-sys)$" }, animation = "popin" })

-- --- Thunar ---
hl.window_rule({ match = { class = "^(thunar)$" }, animation = "popin" })
hl.window_rule({ match = { class = "^(thunar)$" }, opacity = "0.8 0.8" })

-- --- VSCodium & Chromium ---
hl.window_rule({ match = { class = "^(VSCodium)$" }, opacity = "0.8 0.8" })
hl.window_rule({ match = { class = "^(chromium)$" }, animation = "popin" })

-- --- Wofi (Layer Rules) ---
-- Note: 'move cursor' no longer exists in Hyprland. 
-- Also, set Wofi's opacity inside your ~/.config/wofi/style.css instead of here.
hl.layer_rule({ match = { namespace = "wofi" }, no_anim = true })

-- --- Zen Browser Opacity ---
-- hl.window_rule({ match = { class = "^(zen)$" }, opacity = "0.85 0.75" })

-- --- Ibus UI ---
hl.window_rule({ match = { class = "^(ibus-ui-gtk3)$" }, float = true })
hl.window_rule({ match = { class = "^(ibus-ui-gtk3)$" }, no_focus = true })

-- messenger
hl.window_rule({
    name = "capture-messenger",
    match = { title = ".*[Mm]essenger.*" },
    workspace = "special:messenger silent",
    float = true,
    size = "1000 750",
    center = true,
})

-- See https://wiki.hyprland.org/Configuring/Keywords/ for more
local mainMod = "SUPER"

-- Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more

hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload")) -- reload hyperland 
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty")) --open the terminal
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close()) -- close the active window
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })) -- turns active window to fullscreen (hides waybar)
hl.bind(mainMod .. " + SHIFT + semicolon", hl.dsp.exec_cmd("hyprlock")) -- Lock the screen
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("wlogout --protocol layer-shell")) -- show the logout window
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit()) -- Exit Hyprland all together no (force quit Hyprland)
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser")) -- Open Zen Browser
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("kitty -e nvim")) -- Open nvim
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar")) -- Show the graphical file browser
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" })) -- Allow a window to float
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("wofi")) -- Show the graphicall app launcher
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("wofi-calc")) -- Show the graphicall app launcher
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle

hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]])) -- take a screenshot
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --style ~/.config/wofi/config --style ~/.config/wofi/style.css --dmenu | cliphist decode | wl-copy")) -- open clipboard manager
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("~/.config/HyprV/hyprv_util vswitch")) -- switch HyprV version
hl.bind(mainMod .. " + SEMICOLON", hl.dsp.exec_cmd("/usr/bin/wofi-emoji"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("~/.config/hypr/tmux-session-switcher.sh"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("swaync-client -t -sw")) -- toggle notification center

-- Move focus with mainMod + hjkl 
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Resize
hl.bind(mainMod .. " + comma", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
hl.bind(mainMod .. " + period", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
hl.bind(mainMod .. " + u", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
hl.bind(mainMod .. " + i", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))


-- Switch workspaces with mainMod + [0-9]
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move active window to a workspace with mainMod + SHIFT + [0-9]
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1, follow = true }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2, follow = true }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3, follow = true }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4, follow = true }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5, follow = true }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6, follow = true }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7, follow = true }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8, follow = true }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9, follow = true }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10, follow = true }))

-- Move window
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
