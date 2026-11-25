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

-- Cascade, as on Windows 11: floating windows on a workspace open a step
-- down and to the right of the previous one, so every window stays reachable
-- instead of stacking exactly on top of the last (several same-size windows
-- would otherwise be pixel-perfect on top of each other). window.open fires
-- before the window settles — its position and size are not final yet — so
-- the cascade waits until the geometry stops changing. When the next step
-- would leave the work area, the cascade restarts one step in from the
-- first window; a workspace with no windows left starts over.
local muhos_cascade = {} -- workspace id -> { ox, oy, x, y }
local muhos_min_home = {} -- address -> workspace name a minimized window returns to
local MUHOS_CASCADE = { x = 40, y = 32 }

local function muhos_num(v) return tonumber(v) or 0 end

local function muhos_window_rect(w)
  local a, s = w.at or {}, w.size or {}
  return {
    x = muhos_num(a.x or a[1]), y = muhos_num(a.y or a[1]),
    w = muhos_num(s.x or s[1]), h = muhos_num(s.y or s[2]),
  }
end

local function muhos_workarea(win)
  local m = win.monitor
  if not m then return nil end
  local res = m.reserved or {}
  local scale = (m.scale and m.scale > 0) and m.scale or 1
  local left = muhos_num(m.x) + muhos_num(res.left)
  local top = muhos_num(m.y) + muhos_num(res.top)
  return {
    x = left, y = top,
    x2 = muhos_num(m.x) + muhos_num(m.width) / scale - muhos_num(res.right),
    y2 = muhos_num(m.y) + muhos_num(m.height) / scale - muhos_num(res.bottom),
  }
end

local function muhos_cascade_window(win, r)
  local ws = win.workspace
  local st = muhos_cascade[ws.id]
  local area = muhos_workarea(win)
  -- A window that already fills the work area (zoom, or an app that opened
  -- large) stays where it is; it only becomes the cascade's reference point.
  if area and r.w >= area.x2 - area.x - 16 and r.h >= area.y2 - area.y - 16 then
    muhos_cascade[ws.id] = { ox = r.x, oy = r.y, x = r.x, y = r.y }
    return
  end
  if not st then
    muhos_cascade[ws.id] = { ox = r.x, oy = r.y, x = r.x, y = r.y }
    return
  end
  local fits = function(x, y)
    return not area or (x >= area.x and y >= area.y
      and x + r.w <= area.x2 - 8 and y + r.h <= area.y2 - 8)
  end
  local nx, ny = st.x + MUHOS_CASCADE.x, st.y + MUHOS_CASCADE.y
  if not fits(nx, ny) then
    nx, ny = st.ox + MUHOS_CASCADE.x, st.oy + MUHOS_CASCADE.y
  end
  -- Never land exactly on another window (a restarted cascade can).
  for _ = 1, 12 do
    local taken = false
    for _, o in ipairs(ws:get_windows() or {}) do
      if o.address ~= win.address and o.floating and not o.hidden then
        local or_ = muhos_window_rect(o)
        if math.abs(or_.x - nx) < 8 and math.abs(or_.y - ny) < 8 then taken = true break end
      end
    end
    if not taken then break end
    nx, ny = nx + MUHOS_CASCADE.x, ny + MUHOS_CASCADE.y
    if area then
      nx = math.max(area.x, math.min(nx, area.x2 - r.w - 8))
      ny = math.max(area.y, math.min(ny, area.y2 - r.h - 8))
    end
  end
  if area then
    nx = math.max(area.x, math.min(nx, area.x2 - r.w - 8))
    ny = math.max(area.y, math.min(ny, area.y2 - r.h - 8))
  end
  st.x, st.y = nx, ny
  hl.dispatch(hl.dsp.window.move({ x = nx, y = ny, window = "address:" .. win.address }))
end

hl.on("window.open", function(w)
  if not w or w.pinned then return end
  local addr = w.address
  local last, stable, tries = nil, 0, 0
  -- hl.timer has no cancel(); each poll re-arms a oneshot and simply stops
  -- re-arming when the window settles or the attempt cap is hit.
  local function poll()
    tries = tries + 1
    local win = hl.get_window("address:" .. addr)
    if win and win.mapped and not win.hidden and win.floating
       and win.workspace and not win.workspace.special and not win.group
       and (not win.fullscreen or win.fullscreen == 0) then
      local r = muhos_window_rect(win)
      stable = (last and r.x == last.x and r.y == last.y and r.w == last.w and r.h == last.h) and stable + 1 or 0
      last = r
      if stable >= 2 or tries >= 25 then
        muhos_cascade_window(win, r)
        return
      end
    elseif tries >= 25 then
      return
    end
    hl.timer(poll, { timeout = 60, type = "oneshot" })
  end
  hl.timer(poll, { timeout = 60, type = "oneshot" })
end)

hl.on("window.destroy", function(w)
  if not w then return end
  muhos_min_home[w.address] = nil
  local ws = w.workspace
  if ws and not ws.special and #(ws:get_windows() or {}) == 0 then
    muhos_cascade[ws.id] = nil
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
-- minimized window waits on the hidden workspace "special:minimized" and
-- comes back to the workspace it left, as on Windows and GNOME; the dock
-- restores through muhos_restore_window below. Music moves from Super+M to
-- Super+Shift+M.
local function muhos_minimize(w)
  if not w then return end
  if w.workspace and not w.workspace.special then
    muhos_min_home[w.address] = w.workspace.name or "e+0"
  end
  hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = "address:" .. w.address, follow = false }))
end
local function muhos_restore(addr)
  local home = muhos_min_home[addr] or "e+0"
  muhos_min_home[addr] = nil
  hl.dispatch(hl.dsp.window.move({ workspace = home, window = "address:" .. addr, follow = true }))
end
-- Called from the shell (MuhosState.restoreWindow) via `hyprctl eval`.
function muhos_restore_window(addr)
  if not addr then return end
  local a = tostring(addr):gsub("^address:", "")
  if not a:match("^0x") then a = "0x" .. a end
  muhos_restore(a)
end
hl.on("window.minimize", function(w, minimized)
  if not w then return end
  if minimized then
    muhos_minimize(w)
  else
    muhos_restore(w.address)
  end
end)
hl.unbind(mainMod .. " + M")
hl.bind(mainMod .. " + M", function() muhos_minimize(hl.get_active_window()) end)
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("serpantinum msg toggle music"))

-- Mission Control, as on macOS: every window on the workspace side by side.
-- Super+G, or swipe up with three fingers.
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("serpantinum ipc call muhos missionControl"))
hl.gesture({ fingers = 3, direction = "up", action = {
  finish = function() hl.dispatch(hl.dsp.exec_cmd("serpantinum ipc call muhos missionControl")) end,
} })
