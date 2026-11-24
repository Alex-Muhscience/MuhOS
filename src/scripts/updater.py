import json
import os
import re
import sys
import time
import urllib.request

REPO = "ilyamiro/serpantinum"
DEFAULT_VER = "2.0.0"

state_dir = os.path.expanduser("~/.local/state/serpantinum")
if "--state-dir" in sys.argv:
    try:
        idx = sys.argv.index("--state-dir")
        if idx + 1 < len(sys.argv):
            state_dir = sys.argv[idx + 1]
    except Exception:
        pass

package_managed = os.path.isfile(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
    "package-managed",
))

state_file = os.path.join(state_dir, "version")
last_check_file = os.path.join(state_dir, "last_check")
notified_file = os.path.join(state_dir, "last_notified")

if "--save-notified" in sys.argv:
    try:
        idx = sys.argv.index("--save-notified")
        if idx + 1 < len(sys.argv):
            ver_to_save = sys.argv[idx + 1]
            os.makedirs(state_dir, exist_ok=True)
            with open(notified_file, "w") as f:
                f.write(ver_to_save)
    except Exception:
        pass
    sys.exit(0)

if "--delay" in sys.argv:
    if os.path.isfile(last_check_file):
        try:
            with open(last_check_file, "r") as f:
                last_ts = float(f.read().strip())
            elapsed = time.time() - last_ts
            remaining = int(max(0, 3600 - elapsed) * 1000)
            print(remaining)
            sys.exit(0)
        except Exception:
            pass
    print(0)
    sys.exit(0)

def get_local_ver():
    if os.path.isfile(state_file):
        try:
            with open(state_file, "r") as f:
                for line in f:
                    if line.startswith("SERPANTINUM_VERSION="):
                        v = line.split("=", 1)[1].strip().strip('"').strip("'")
                        if v:
                            return v
        except Exception:
            pass
    return DEFAULT_VER

def get_last_notified():
    if os.path.isfile(notified_file):
        try:
            with open(notified_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return ""

def parse_v(v):
    nums = re.findall(r"\d+", v)
    return [int(x) for x in nums] if nums else [0]

try:
    os.makedirs(state_dir, exist_ok=True)
    with open(last_check_file, "w") as f:
        f.write(str(time.time()))
except Exception:
    pass

local_ver = get_local_ver()
remote_ver = local_ver


def installed_muhos():
    """The installed muhos package as VERSION-RELEASE without the dist tag."""
    import subprocess
    try:
        out = subprocess.run(["rpm", "-q", "--qf", "%{VERSION}-%{RELEASE}", "muhos"],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return None
    return re.sub(r"\.fc\d+$", "", out.stdout.strip()) if out.returncode == 0 else None


def muhos_versions():
    """MuhOS (package-managed): the installed muhos package and the newest
    MuhOS release's package for this Fedora version, as VERSION-RELEASE
    without the dist tag (e.g. 0.1.0-0.16). Asked only on demand (when
    Settings opens), never by the background timers."""
    import json as _json
    local = installed_muhos()
    if not local:
        return None
    fedora = ""
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("VERSION_ID="):
                    fedora = line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    req = urllib.request.Request(
        "https://api.github.com/repos/Alex-Muhscience/MuhOS/releases?per_page=1",
        headers={"User-Agent": "muhos-updater", "Accept": "application/vnd.github+json"})
    releases = _json.loads(urllib.request.urlopen(req, timeout=5).read().decode("utf-8"))
    remote = local
    for asset in (releases[0].get("assets", []) if releases else []):
        m = re.match(r"muhos-(\d[^-]*-[^-]+?)\.fc(\d+)\.noarch\.rpm$", asset.get("name", ""))
        if m and (not fedora or m.group(2) == fedora):
            remote = m.group(1)
    return local, remote


if package_managed:
    local_ver = re.sub(r"\.fc\d+$", "", local_ver)
    if "--background" not in sys.argv:
        try:
            found = muhos_versions()
            if found:
                local_ver, remote_ver = found
        except Exception:
            remote_ver = local_ver
    else:
        local_ver = installed_muhos() or local_ver
        remote_ver = local_ver

if not package_managed:
    try:
        req = urllib.request.Request(
            f"https://raw.githubusercontent.com/{REPO}/master/version.txt",
            headers={"User-Agent": "updater-script"}
        )
        res = urllib.request.urlopen(req, timeout=5)
        remote_ver = res.read().decode("utf-8").strip()
    except Exception:
        remote_ver = local_ver

has_update = parse_v(remote_ver) > parse_v(local_ver)

print(json.dumps({
    "local": local_ver,
    "remote": remote_ver,
    "has_update": has_update,
    "last_notified": get_last_notified()
}))
