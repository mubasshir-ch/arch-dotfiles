local SCRIPT = "~/.config/HyprV/waybar/scripts"

hl.bind("xf86audioraisevolume", hl.dsp.exec_cmd(SCRIPT .. "/volume --inc"))
hl.bind("xf86audiolowervolume", hl.dsp.exec_cmd(SCRIPT .. "/volume --dec"))
hl.bind("xf86AudioMicMute",     hl.dsp.exec_cmd(SCRIPT .. "/volume --toggle-mic"))
hl.bind("xf86audioMute",        hl.dsp.exec_cmd(SCRIPT .. "/volume --toggle"))

hl.bind("xf86KbdBrightnessDown", hl.dsp.exec_cmd(SCRIPT .. "/kb-brightness --dec"))
hl.bind("xf86KbdBrightnessUp",   hl.dsp.exec_cmd(SCRIPT .. "/kb-brightness --inc"))

hl.bind("xf86MonBrightnessDown", hl.dsp.exec_cmd(SCRIPT .. "/brightness --dec"))
hl.bind("xf86MonBrightnessUp",   hl.dsp.exec_cmd(SCRIPT .. "/brightness --inc"))
