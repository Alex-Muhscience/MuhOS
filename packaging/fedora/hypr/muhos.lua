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

-- Focus works as on macOS. A click focuses a window and brings it to the
-- front; merely passing the pointer over a window behind does not (with
-- focus following the mouse, typing went to a window hidden behind the one
-- in front). Apps may bring their own new windows forward, e.g. a browser
-- opening a window for another profile.
hl.config({
  input = { follow_mouse = 2 },
  misc = { focus_on_activate = true },
})

-- Switch windows: Super+Tab (or Alt+Tab) cycles through the windows on the
-- workspace and brings each to the front; add Shift to go backwards.
for _, mod in ipairs({ "SUPER", "ALT" }) do
  hl.bind(mod .. " + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = true }))
    hl.dispatch(hl.dsp.window.bring_to_top())
  end)
  hl.bind(mod .. " + SHIFT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
  end)
end

-- Cascade: a new window that would open exactly on top of another one on
-- its workspace moves down and to the right, so both stay reachable.
hl.on("window.open", function(w)
  if not w or not w.floating or not w.workspace then return end
  local pos = function(win) local a = win.at or {} return a.x or a[1] or 0, a.y or a[2] or 0 end
  local x, y = pos(w)
  local taken = true
  local tries = 0
  while taken and tries < 12 do
    taken = false
    for _, o in ipairs(w.workspace:get_windows()) do
      if o.address ~= w.address and o.floating and not o.hidden then
        local ox, oy = pos(o)
        if math.abs(ox - x) < 8 and math.abs(oy - y) < 8 then taken = true break end
      end
    end
    if taken then x, y = x + 32, y + 32 tries = tries + 1 end
  end
  if tries > 0 then
    hl.dispatch(hl.dsp.window.move({ x = 32 * tries, y = 32 * tries, relative = true }))
  end
end)

-- Zoom, as on macOS. Hyprland maximizes a window by giving it a kind of full
-- screen (mode 1): it is then drawn above every other window on the
-- workspace and takes focus back, so other windows seem frozen until it
-- closes (e.g. a terminal behind a Chrome window that opened maximized).
-- Instead, a floating window that gets maximized (by the app, its zoom
-- button or Super+Alt+F) becomes an ordinary window filling the space
-- Hyprland gave it, between the menu bar and the dock, that other windows
-- can still go on top of. Zooming a zoomed window restores its old size.
-- Real full screen (mode 2: F11, videos) is unchanged.
local muhos_zoom = {} -- address -> { zoomed = {x, y, w, h}, before = {x, y, w, h} } while zoomed
local function muhos_rect(w)
  local a, s = w.at or {}, w.size or {}
  return { a.x or a[1] or 0, a.y or a[2] or 0, s.x or s[1] or 0, s.y or s[2] or 0 }
end
local function muhos_place(addr, r)
  hl.dispatch(hl.dsp.window.resize({ x = r[3], y = r[4], window = addr }))
  hl.dispatch(hl.dsp.window.move({ x = r[1], y = r[2], window = addr }))
end
hl.on("window.fullscreen", function(w)
  if not w or w.fullscreen ~= 1 or not w.floating then return end
  local addr = "address:" .. w.address
  local target = muhos_rect(w) -- where Hyprland put the maximized window
  -- Leave Hyprland's maximize, and tell the app it is not maximized:
  -- Hyprland ignores "unmaximize" from a window it doesn't see as
  -- maximized, so the app's next click on zoom must ask to maximize again,
  -- and that comes back here as "restore".
  hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = addr }))
  local z = muhos_zoom[w.address]
  if z then
    muhos_zoom[w.address] = nil
    muhos_place(addr, z.before)
  else
    muhos_zoom[w.address] = { zoomed = target, before = muhos_rect(w) }
    muhos_place(addr, target)
  end
end)
hl.on("window.close", function(w) if w then muhos_zoom[w.address] = nil end end)

-- Minimize, as on macOS: Super+M (like Cmd+M), the app menu and the dock.
-- Apps' own minimize requests never reach Hyprland's config, but the
-- shell's do (foreign toplevel), as window.minimize(window, true|false). A
-- minimized window waits on the hidden workspace "special:minimized"; the
-- dock brings it back. Music moves from Super+M to Super+Shift+M.
local function muhos_minimize(w)
  if not w then return end
  hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = "address:" .. w.address, follow = false }))
end
hl.on("window.minimize", function(w, minimized)
  if not w then return end
  if minimized then
    muhos_minimize(w)
  else
    hl.dispatch(hl.dsp.window.move({ workspace = "e+0", window = "address:" .. w.address }))
  end
end)
hl.unbind(mainMod .. " + M")
hl.bind(mainMod .. " + M", function() muhos_minimize(hl.get_active_window()) end)
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("serpantinum msg toggle music"))
