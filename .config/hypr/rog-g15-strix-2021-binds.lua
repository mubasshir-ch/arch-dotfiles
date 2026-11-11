-- ROG G15 Strix (2021) Specific binds
hl.bind("code:156", hl.dsp.exec_cmd("rog-control-center")) -- ASUS Armory crate key
hl.bind("code:211", hl.dsp.exec_cmd("asusctl profile -n; pkill -SIGRTMIN+8 waybar")) -- Fan Profile key switch between power profiles
hl.bind("code:210", hl.dsp.exec_cmd("asusctl led-mode -n")) -- Switch keyboard RGB profile FN+F4
