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
