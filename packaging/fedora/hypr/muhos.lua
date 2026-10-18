-- MuhOS (Fedora): compositor rules for the MuhOS shell's own surfaces.
-- Panels named "muhos-*" are drawn semi-transparent; Hyprland blurs what is
-- behind them (the "clean glass" look). Fully transparent pixels stay sharp.
hl.layer_rule({ name = "muhos-glass", match = { namespace = "^muhos-" }, blur = true, ignore_alpha = 0.1 })
