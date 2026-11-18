// VoidTweaks site config — edit these, no other code changes needed.
window.VT = {
  github: "https://github.com/VoidUserFR/VoidTweaks-Windows",
  releases: "https://github.com/VoidUserFR/VoidTweaks-Windows/releases/latest",

  // ── DOWNLOAD / monetization ──────────────────────────────────────────────
  // Paste your link-locker URL (work.ink / Lootlabs / Linkvertise) here.
  // The locker's DESTINATION should be the GitHub release (or a direct asset).
  // Leave "" to send the Download button straight to GitHub (no ad-step).
  lockerUrl: "",            // e.g. "https://work.ink/xxxx/voidtweaks"
  lockerName: "work.ink",   // shown in the popup; cosmetic

  // Always show an honest "no ads? GitHub →" fallback inside the popup.
  showGithubFallback: true,
};

window.VT.downloadUrl = window.VT.lockerUrl && window.VT.lockerUrl.trim()
  ? window.VT.lockerUrl.trim()
  : window.VT.releases;

(function () {
  var locked = !!(window.VT.lockerUrl && window.VT.lockerUrl.trim());

  // ── Inline popup (projectreal.gg style) — built once, reused everywhere ──
  function buildModal() {
    var o = document.createElement("div");
    o.className = "vt-ov";
    o.innerHTML =
      '<div class="vt-modal" role="dialog" aria-modal="true" aria-label="Download VoidTweaks">' +
        '<button class="vt-x" aria-label="Close">&times;</button>' +
        '<img class="vt-logo" src="assets/logo.png" alt="" />' +
        '<h3>Get VoidTweaks — free</h3>' +
        '<p class="vt-sub">One quick checkpoint via <b>' + window.VT.lockerName + '</b> keeps the project running. ' +
        'It takes a few seconds and lands you on the real download.</p>' +
        '<div class="vt-step"><span class="vt-badge">1</span> Click <b>Continue</b> → finish the ' + window.VT.lockerName + ' step → your download starts.</div>' +
        '<a class="btn primary vt-go" href="' + window.VT.lockerUrl.trim() + '" target="_blank" rel="noopener">Continue → get download ↗</a>' +
        (window.VT.showGithubFallback
          ? '<a class="vt-skip" href="' + window.VT.releases + '" target="_blank" rel="noopener">No ads? Grab it on GitHub →</a>'
          : '') +
      '</div>';
    document.body.appendChild(o);
    function close() { o.classList.remove("open"); }
    o.addEventListener("click", function (e) { if (e.target === o) close(); });
    o.querySelector(".vt-x").addEventListener("click", close);
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") close(); });
    return o;
  }
  var modal = locked ? buildModal() : null;

  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll('[data-vt="github"]').forEach(function (a) { a.href = window.VT.github; });
    document.querySelectorAll('[data-vt="releases"]').forEach(function (a) { a.href = window.VT.releases; });

    document.querySelectorAll('[data-vt="download"]').forEach(function (a) {
      if (locked) {
        a.href = window.VT.lockerUrl.trim();      // still works if JS fails
        a.addEventListener("click", function (e) {
          e.preventDefault();
          modal.classList.add("open");
        });
      } else {
        a.href = window.VT.releases;              // no locker → straight to GitHub
      }
    });

    // The small "ad-step" note under buttons shows only when a locker is set.
    document.querySelectorAll('[data-vt-fallback]').forEach(function (el) {
      el.style.display = locked ? "" : "none";
      el.querySelectorAll('[data-vt="releases"]').forEach(function (a) { a.href = window.VT.releases; });
    });
  });
})();
