-- MuhOS (Fedora): replaces upstream config/autostart.lua.
-- The shell runs as a systemd user service bound to the session instead of
-- being spawned directly, and no services are enabled persistently.
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE PATH && systemctl --user start muhos-session.target")
end)
