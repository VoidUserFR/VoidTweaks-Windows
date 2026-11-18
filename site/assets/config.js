// VoidTweaks site config — edit these, no other code changes needed.
window.VT = {
  github: "https://github.com/VoidUserFR/VoidTweaks-Windows",
  releases: "https://github.com/VoidUserFR/VoidTweaks-Windows/releases/latest",

  // ── DOWNLOAD / monetization ──────────────────────────────────────────────
  // Paste your link-locker URL (work.ink / Lootlabs / Linkvertise) here.
  // The locker's DESTINATION should be the GitHub release (or a direct asset).
  // Leave "" to send the Download button straight to GitHub (no ad-step).
  lockerUrl: "",            // e.g. "https://work.ink/xxxx/voidtweaks"
  lockerName: "work.ink",   // shown on the ad-step note; cosmetic

  // Always show an honest "no ads? GitHub →" fallback next to the button.
  showGithubFallback: true,
};

// Resolve where the primary Download button points.
window.VT.downloadUrl = window.VT.lockerUrl && window.VT.lockerUrl.trim()
  ? window.VT.lockerUrl.trim()
  : window.VT.releases;

// Wire every element that opts in: data-vt="download" | "github" | "releases",
// and reveal fallbacks marked data-vt-fallback (hidden until a locker is set).
document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll('[data-vt="download"]').forEach(function (a) { a.href = window.VT.downloadUrl; });
  document.querySelectorAll('[data-vt="github"]').forEach(function (a) { a.href = window.VT.github; });
  document.querySelectorAll('[data-vt="releases"]').forEach(function (a) { a.href = window.VT.releases; });
  var locked = !!(window.VT.lockerUrl && window.VT.lockerUrl.trim());
  document.querySelectorAll('[data-vt-fallback]').forEach(function (el) {
    el.style.display = (locked && window.VT.showGithubFallback) ? "" : "none";
    el.querySelectorAll('[data-vt="releases"]').forEach(function (a) { a.href = window.VT.releases; });
  });
});
