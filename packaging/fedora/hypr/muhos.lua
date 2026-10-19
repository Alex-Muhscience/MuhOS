-- MuhOS (Fedora): compositor rules for the MuhOS shell's own surfaces.
-- Hyprland blurs what is behind their translucent parts (the "liquid glass"
-- look); pixels below ignore_alpha stay sharp.
-- Menu bar: only the clock island is glass; the faint shade under the bar
-- (alpha < 0.3) is not blurred.
hl.layer_rule({ name = "muhos-bar-glass", match = { namespace = "^muhos-bar$" }, blur = true, ignore_alpha = 0.3 })
-- Control centre and welcome screen.
hl.layer_rule({ name = "muhos-panel-glass", match = { namespace = "^muhos-(panel|welcome)$" }, blur = true, ignore_alpha = 0.1 })
