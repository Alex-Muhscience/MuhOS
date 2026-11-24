-- MuhOS (Fedora): compositor settings for the MuhOS shell's glass.

-- Frosted glass, as on macOS: a wide, smooth blur with a saturation boost
-- ("vibrancy") and a faint grain, so translucent panels read as frosted glass
-- rather than smeared colour.
hl.config({
  decoration = {
    blur = {
      size = 10,
      passes = 3,
      vibrancy = 0.35,
      noise = 0.02,
      contrast = 1.0,
    },
  },
})

-- Blur behind the shell's own surfaces. Pixels below ignore_alpha stay sharp:
-- the bar's faint shade and the panels' soft shadows (both under 0.3) are not
-- blurred, only the glass itself.
hl.layer_rule({ name = "muhos-glass", match = { namespace = "^muhos-(bar|panel|dock|welcome)$" }, blur = true, ignore_alpha = 0.3 })

-- Windows float and overlap, as on macOS: each opens centred at the size the
-- app asks for. Super+T tiles (or floats again) the focused window.
hl.window_rule({ name = "muhos-float", match = { class = ".*" }, float = true, center = true })
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
