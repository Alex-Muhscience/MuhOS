#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# MuhOS: show the desktop's file chooser and print the chosen path.
#
#   pick_file.py picture [START_DIR]    an image or video (for the wallpaper)
#   pick_file.py folder  [START_DIR]    a folder
#
# Uses the XDG desktop portal (the GNOME file chooser under MuhOS), so every
# disk, mounted drive and bookmark is reachable. Falls back to zenity. Prints
# nothing and exits 1 when cancelled.

import os
import secrets
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse

IMAGES = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp",
          "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.BMP"]
VIDEOS = ["*.mp4", "*.mkv", "*.mov", "*.webm", "*.MP4", "*.MKV", "*.MOV", "*.WEBM"]


def portal(kind, start):
    from jeepney import DBusAddress, MatchRule, message_bus, new_method_call
    from jeepney.io.blocking import Proxy, open_dbus_connection

    conn = open_dbus_connection(bus="SESSION")
    try:
        token = "muhos" + secrets.token_hex(6)
        sender = conn.unique_name[1:].replace(".", "_")
        handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
        rule = MatchRule(type="signal", interface="org.freedesktop.portal.Request",
                         member="Response", path=handle)
        Proxy(message_bus, conn).AddMatch(rule)
        options = {"handle_token": ("s", token), "modal": ("b", True)}
        if kind == "folder":
            options["directory"] = ("b", True)
            title = "Choose a wallpaper folder"
        else:
            pictures = ("Pictures", [(0, p) for p in IMAGES])
            videos = ("Videos", [(0, p) for p in VIDEOS])
            options["filters"] = ("a(sa(us))", [pictures, videos])
            options["current_filter"] = ("(sa(us))", pictures)
            title = "Choose a wallpaper"
        if start and os.path.isdir(start):
            options["current_folder"] = ("ay", os.fsencode(start) + b"\0")
        addr = DBusAddress("/org/freedesktop/portal/desktop", bus_name="org.freedesktop.portal.Desktop",
                           interface="org.freedesktop.portal.FileChooser")
        with conn.filter(rule) as queue:
            reply = conn.send_and_get_reply(new_method_call(addr, "OpenFile", "ssa{sv}", ("", title, options)))
            if reply.header.message_type.name == "error":
                raise RuntimeError(reply.body)
            response = conn.recv_until_filtered(queue)
        code, results = response.body
        if code != 0:
            return None                       # cancelled
        uris = results.get("uris", ("as", []))[1]
        return unquote(urlparse(uris[0]).path) if uris else None
    finally:
        conn.close()


def zenity(kind, start):
    cmd = ["zenity", "--file-selection"]
    if kind == "folder":
        cmd += ["--directory", "--title=Choose a wallpaper folder"]
    else:
        cmd += ["--title=Choose a wallpaper", "--file-filter=Pictures | " + " ".join(IMAGES),
                "--file-filter=Videos | " + " ".join(VIDEOS)]
    if start and os.path.isdir(start):
        cmd.append("--filename=" + start.rstrip("/") + "/")
    out = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
    return out.stdout.strip() if out.returncode == 0 else None


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "picture"
    start = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/Pictures")
    try:
        path = portal(kind, start)
    except Exception:
        if not shutil.which("zenity"):
            return 2
        path = zenity(kind, start)
    if not path:
        return 1
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
