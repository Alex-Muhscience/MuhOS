-- MuhOS Hyprland configuration.
--
-- This file was created once by muhos-session and is yours; package updates
-- never overwrite it. It loads the MuhOS defaults shipped by the package, then
-- your own settings from user.lua in this directory, if that file exists.
-- Put your changes in user.lua so you keep receiving updated defaults.

local defaults = "@MUHOS_HYPR_DIR@"
package.path = defaults .. "/?.lua;" .. package.path
dofile(defaults .. "/hyprland.lua")

local ok, err = pcall(require, "user")
if not ok and not tostring(err):find("module 'user' not found", 1, true) then
  error(err)
end
