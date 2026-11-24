hl.config({
  general = {
    border_size = 0,
    gaps_in = 4,
    gaps_out = 8,
    float_gaps = 8,
    resize_on_border = true,
    extend_border_grab_area = 30,
  },

  decoration = {
    rounding = 12,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      new_optimizations = true,
    },
    shadow = {
      enabled = true,
      range = 8,
      render_power = 3,
      offset = { 0, 4 },
      scale = 0.9,
      color = "rgba(00000059)",
    },
  },

  input = {
    kb_layout = "us",
    kb_options = "grp:alt_shift_toggle",
    accel_profile = "flat",
    touchpad = {
      natural_scroll = true,
      disable_while_typing = false,
    },
  },

  misc = {
    focus_on_activate = false,
    font_family = "Adwaita Sans",
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})

hl.curve("macos", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1} } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "macos", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "macos", style = "popin 90%" })
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "macos", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "macos", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "macos", style = "fade" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "macos" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "macos", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 4, bezier = "macos", style = "fade" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3, bezier = "macos", style = "fade" })
