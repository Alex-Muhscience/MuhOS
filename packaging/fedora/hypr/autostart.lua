-- MuhOS (Fedora): replaces upstream config/autostart.lua.
-- The shell runs as a systemd user service bound to the session instead of
-- being spawned directly, and no services are enabled persistently.
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  -- DCONF_PROFILE and GTK_THEME (set by muhos-session) reach D-Bus services
  -- too, and portals already running (started for an earlier session) are
  -- restarted so apps get MuhOS's settings through them.
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE PATH DCONF_PROFILE GTK_THEME"
    .. " ; dbus-update-activation-environment --systemd DCONF_PROFILE GTK_THEME"
    .. " ; systemctl --user try-restart xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service xdg-desktop-portal.service"
    .. " ; systemctl --user start muhos-session.target")
end)
