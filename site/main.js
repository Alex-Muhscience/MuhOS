// SPDX-License-Identifier: AGPL-3.0-or-later
// MuhOS website: copy buttons on commands, and the newest release on the
// download page (read from GitHub's public API; the page links to the
// releases list if that fails).

const REPO = "Alex-Muhscience/MuhOS";

for (const pre of document.querySelectorAll("pre[data-copy]")) {
  const button = document.createElement("button");
  button.className = "copy";
  button.type = "button";
  button.textContent = "Copy";
  button.addEventListener("click", async () => {
    const text = [...pre.querySelectorAll("code")].map(c => c.innerText).join("\n")
      .split("\n").map(line => line.replace(/\s+#.*$/, "")).join("\n").trim();
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = "Copied";
    } catch {
      button.textContent = "Select and copy";
    }
    setTimeout(() => { button.textContent = "Copy"; }, 1800);
  });
  pre.appendChild(button);
}

function formatSize(bytes) {
  return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB";
}

async function showRelease() {
  const box = document.getElementById("release");
  if (!box) return;
  try {
    // The list includes pre-releases, which /releases/latest leaves out.
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=1`);
    if (!response.ok) throw new Error(response.status);
    const [release] = await response.json();
    if (!release) throw new Error("no releases");

    const date = new Date(release.published_at).toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" });
    box.querySelector(".version").innerHTML = "";
    box.querySelector(".version").append(release.name || release.tag_name);
    if (release.prerelease) {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = "Pre-release";
      box.querySelector(".version").append(badge);
    }
    box.querySelector(".meta").textContent = `${release.tag_name} · ${date}`;
    box.querySelector(".btn").href = release.html_url;

    const list = document.getElementById("files");
    list.innerHTML = "";
    const order = name => /\.src\.rpm$/.test(name) ? 2 : name === "SHA256SUMS" ? 1 : 0;
    const assets = [...release.assets].sort((a, b) => order(a.name) - order(b.name) || a.name.localeCompare(b.name));
    for (const asset of assets) {
      const item = document.createElement("li");
      const link = document.createElement("a");
      link.href = asset.browser_download_url;
      link.textContent = asset.name;
      const size = document.createElement("span");
      size.className = "size";
      size.textContent = formatSize(asset.size);
      item.append(link, size);
      list.append(item);
    }
    document.getElementById("files-heading").hidden = false;
  } catch {
    // Keep the static fallback text and link.
  }
}

showRelease();

// Changelog page: every release's notes, as GitHub renders them. The page
// keeps its built-in summary if GitHub can't be reached.
async function showChangelog() {
  const box = document.getElementById("changelog");
  if (!box) return;
  try {
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`, {
      headers: { Accept: "application/vnd.github.html+json" },
    });
    if (!response.ok) throw new Error(response.status);
    const releases = (await response.json()).filter(r => !r.draft);
    if (!releases.length) throw new Error("no releases");

    const entries = releases.map(release => {
      const entry = document.createElement("article");
      entry.className = "entry";
      entry.id = release.tag_name;

      const title = document.createElement("h2");
      title.append(release.name || release.tag_name);
      if (release.prerelease) {
        const badge = document.createElement("span");
        badge.className = "badge";
        badge.textContent = "Pre-release";
        title.append(badge);
      }
      const meta = document.createElement("p");
      meta.className = "meta";
      const date = new Date(release.published_at).toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" });
      const link = document.createElement("a");
      link.href = release.html_url;
      link.textContent = release.tag_name;
      meta.append(link, ` · ${date}`);

      const body = document.createElement("div");
      body.className = "body";
      // GitHub's own rendering of this repository's release notes (sanitised by GitHub).
      body.innerHTML = release.body_html || "";
      for (const table of body.querySelectorAll("table")) {
        const wrap = document.createElement("div");
        wrap.className = "table-wrap";
        table.replaceWith(wrap);
        wrap.append(table);
      }
      entry.append(title, meta, body);
      return entry;
    });
    const more = box.querySelector(".more");
    box.replaceChildren(...entries, ...(more ? [more] : []));
    if (location.hash) document.getElementById(decodeURIComponent(location.hash.slice(1)))?.scrollIntoView();
  } catch {
    // Keep the summary that is already on the page.
  }
}

showChangelog();
