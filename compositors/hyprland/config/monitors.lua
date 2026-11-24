-- Scale "auto" lets Hyprland pick from the screen's size and resolution (2 on
-- a 15.6-inch 4K laptop); a fixed 1.0 made everything tiny on HiDPI screens.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})
