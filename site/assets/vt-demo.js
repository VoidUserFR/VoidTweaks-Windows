/* Live VoidTweaks demo window (html-demo engine, vanilla).
   Recreates the real Optimize view (text rail, profile + search, category
   list with orbit art, Boost/Scan/Apply bar, filter chips, list-style cards)
   and plays it: browse -> toggle a tweak -> apply all shown. */
(function () {
  var mountEl = document.getElementById("vt-demo");
  if (!mountEl || !window.HTMLDemo) return;
  var E = HTMLDemo.ease, G = HTMLDemo.glide;

  // Stage coords (1200x750). Rail 0-128, Cat 128-368, Main 368-1200.
  var SW_X = 1150;            // toggle-switch centre x (far right of a card)
  var CARD_Y = [304, 424, 544, 664];  // card toggle centres, top→bottom
  var APPLY_SHOWN = [1000, 185];       // "Apply all shown" button

  // ── shared UI (one <style> + the three-pane Optimize view) ──
  function shell(cards, appliedN) {
    return (
      '<style>' +
      '.vtd{position:absolute;inset:0;display:flex;background:#0a0812;color:#c7c3dc;font-weight:500;' +
        'font-family:system-ui,"Segoe UI",sans-serif}' +
      /* icon + text rail */
      '.vtd-rail{width:128px;flex:none;background:#0c0a15;border-right:1px solid rgba(255,255,255,.06);' +
        'display:flex;flex-direction:column;gap:6px;padding:18px 12px}' +
      '.vtd-rail .r{display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:11px;' +
        'font-size:14px;color:#8d8aa2}' +
      '.vtd-rail .r b{font-size:16px;width:20px;text-align:center}' +
      '.vtd-rail .r.on{background:rgba(139,124,240,.16);color:#fff;box-shadow:inset 0 0 0 1px rgba(139,124,240,.35)}' +
      /* category column */
      '.vtd-cat{width:240px;flex:none;background:#0b0914;border-right:1px solid rgba(255,255,255,.06);' +
        'padding:16px 14px;position:relative;overflow:hidden}' +
      '.vtd-prof{display:flex;align-items:center;gap:10px;padding:4px 6px 12px}' +
      '.vtd-prof .lg{width:34px;height:34px;border-radius:50%;flex:none;' +
        'background:radial-gradient(circle at 35% 30%,#2a2740,#0c0a15);box-shadow:inset 0 0 0 1px rgba(255,255,255,.12)}' +
      '.vtd-prof .nm{font-size:15px;font-weight:700;color:#f3f2f8;line-height:1.2}' +
      '.vtd-prof .sb{font-size:10.5px;color:#6f6c83;margin-top:2px}' +
      '.vtd-search{display:flex;align-items:center;justify-content:space-between;padding:9px 12px;' +
        'border-radius:9px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.07);' +
        'font-size:12.5px;color:#6f6c83;margin-bottom:10px}' +
      '.vtd-search kbd{font-size:10px;padding:1px 6px;border-radius:5px;background:rgba(255,255,255,.07);color:#9a97ad}' +
      '.vtd-cat a{position:relative;z-index:2;display:flex;justify-content:space-between;align-items:center;' +
        'padding:8px 12px;border-radius:9px;font-size:13.5px;color:#9a97ad}' +
      '.vtd-cat a .n{color:#5f5c74;font-size:11.5px}' +
      '.vtd-cat a.on{background:rgba(139,124,240,.16);color:#fff}' +
      '.vtd-cat a .ic{width:17px;display:inline-block}' +
      '.vtd-orbit{position:absolute;left:4px;bottom:-70px;width:260px;height:260px;z-index:1;opacity:.5;' +
        'pointer-events:none}' +
      '.vtd-orbit i{position:absolute;border-radius:50%;border:1px dashed rgba(139,124,240,.22);' +
        'left:50%;top:50%;transform:translate(-50%,-50%)}' +
      /* main */
      '.vtd-main{flex:1;min-width:0;display:flex;flex-direction:column}' +
      '.vtd-head{padding:16px 24px 6px}' +
      '.vtd-h1{font-size:21px;font-weight:800;color:#f5f4fa;display:flex;align-items:center;gap:9px}' +
      '.vtd-sub{font-size:12.5px;color:#75728a;margin-top:3px}' +
      '.vtd-bar{display:flex;align-items:center;gap:8px;padding:6px 24px 0;flex-wrap:nowrap}' +
      '.vtd-btn{padding:7px 12px;border-radius:8px;font-size:12.5px;font-weight:700;color:#d7d3ea;' +
        'background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.09);white-space:nowrap}' +
      '.vtd-btn.g{color:#0a140e;background:#4cc38a;border-color:transparent}' +
      '.vtd-btn.r{color:#190a0a;background:#ef6a60;border-color:transparent}' +
      '.vtd-btn.go{color:#6fd6a0;background:rgba(76,195,138,.12);border-color:rgba(76,195,138,.4)}' +
      '.vtd-btn.off{opacity:.4}' +
      '.vtd-chk{display:flex;align-items:center;gap:6px;font-size:11.5px;color:#8a879c;margin-left:2px}' +
      '.vtd-chk i{width:14px;height:14px;border-radius:4px;border:1px solid rgba(255,255,255,.2);display:inline-block}' +
      '.vtd-applyshown{margin-left:auto;display:flex;gap:8px}' +
      '.vtd-chips{display:flex;align-items:center;gap:7px;padding:10px 24px 4px;flex-wrap:wrap}' +
      '.vtd-chip{padding:5px 11px;border-radius:999px;font-size:11.5px;color:#9a97ad;' +
        'background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08)}' +
      '.vtd-chip.on{color:#fff;background:rgba(139,124,240,.18);border-color:rgba(139,124,240,.4)}' +
      '.vtd-chip b{color:#c7c3dc}' +
      '.vtd-sep{width:1px;height:18px;background:rgba(255,255,255,.1);margin:0 4px}' +
      '.vtd-badge{display:none;align-items:center;gap:7px;padding:5px 12px;border-radius:999px;' +
        'font-size:12px;font-weight:700;color:#fff;background:rgba(139,124,240,.9);margin-left:4px;' +
        'box-shadow:0 6px 20px rgba(139,124,240,.45)}' +
      '.vtd-badge .d{width:7px;height:7px;border-radius:50%;background:#fff;animation:vtdp 1s ease-in-out infinite}' +
      '@keyframes vtdp{50%{opacity:.4}}' +
      /* card list */
      '.vtd-body{flex:1;padding:12px 24px 18px;display:flex;flex-direction:column;gap:12px;overflow:hidden}' +
      '.vtd-card{position:relative;display:flex;align-items:center;gap:16px;padding:16px 20px 16px 22px;' +
        'background:rgba(255,255,255,.028);border:1px solid rgba(255,255,255,.08);border-radius:14px;' +
        'border-left:3px solid #ef6a60}' +
      '.vtd-card.on{border-left-color:#4cc38a}' +
      '.vtd-ic{width:46px;height:46px;flex:none;border-radius:12px;display:grid;place-items:center;font-size:20px;' +
        'background:rgba(139,124,240,.16);box-shadow:inset 0 0 0 1px rgba(139,124,240,.3)}' +
      '.vtd-cbody{flex:1;min-width:0}' +
      '.vtd-ct{font-size:16px;font-weight:700;color:#f3f2f8}' +
      '.vtd-cd{font-size:12.5px;color:#8f8ca3;margin-top:3px;line-height:1.4}' +
      '.vtd-pills{margin-top:9px;display:flex;align-items:center;gap:8px}' +
      '.vtd-risk{font-size:10px;font-weight:700;letter-spacing:.4px;text-transform:uppercase;padding:3px 8px;' +
        'border-radius:6px;background:rgba(255,255,255,.07);color:#9a97ad}' +
      '.vtd-risk.med{background:rgba(239,179,108,.14);color:#f0bd7a}' +
      '.vtd-admin{font-size:10px;font-weight:700;letter-spacing:.4px;padding:3px 8px;border-radius:6px;' +
        'color:#f0bd7a;border:1px solid rgba(239,179,108,.4)}' +
      '.vtd-cright{flex:none;display:flex;flex-direction:column;align-items:flex-end;gap:9px}' +
      '.vtd-stat{font-size:12px;color:#75728a;display:flex;align-items:center;gap:6px}' +
      '.vtd-stat:after{content:"";width:7px;height:7px;border-radius:50%;background:#75728a}' +
      '.vtd-card.on .vtd-stat{color:#6fd6a0;font-weight:700}' +
      '.vtd-card.on .vtd-stat:after{background:#4cc38a;box-shadow:0 0 8px #4cc38a}' +
      '.vtd-sw{width:46px;height:26px;border-radius:999px;background:#35343f;position:relative}' +
      '.vtd-knob{position:absolute;top:3px;left:3px;width:20px;height:20px;border-radius:50%;background:#fff;' +
        'box-shadow:0 2px 5px rgba(0,0,0,.4)}' +
      '</style>' +
      '<div class="vtd">' +
        '<div class="vtd-rail">' +
          '<div class="r"><b>⌂</b>Home</div>' +
          '<div class="r on"><b>⚡</b>Optimize</div>' +
          '<div class="r"><b>🧰</b>Tools</div>' +
          '<div class="r"><b>🩹</b>Fixes</div>' +
          '<div class="r"><b>⚙</b>Settings</div>' +
        '</div>' +
        '<div class="vtd-cat">' +
          '<div class="vtd-prof"><span class="lg"></span><div>' +
            '<div class="nm">VoidTweaks</div><div class="sb">transparent · reversible · local</div></div></div>' +
          '<div class="vtd-search"><span>Search tweaks…</span><kbd>Ctrl K</kbd></div>' +
          '<a class="on"><span>All</span></a>' +
          '<a><span>Favorites</span></a>' +
          '<a><span>⚠ Needs attention</span></a>' +
          '<a><span class="ic">⚡</span>Performance<span class="n">13</span></a>' +
          '<a><span class="ic">🎮</span>Gaming<span class="n">7</span></a>' +
          '<a><span class="ic">🛡</span>Privacy<span class="n">22</span></a>' +
          '<a><span class="ic">🌐</span>Network<span class="n">14</span></a>' +
          '<a><span class="ic">👁</span>Visual<span class="n">10</span></a>' +
          '<a><span class="ic">📁</span>Explorer<span class="n">16</span></a>' +
          '<a><span class="ic">⚙</span>Advanced<span class="n">6</span></a>' +
          '<div class="vtd-orbit">' +
            '<i style="width:120px;height:120px"></i><i style="width:180px;height:180px"></i>' +
            '<i style="width:240px;height:240px"></i></div>' +
        '</div>' +
        '<div class="vtd-main">' +
          '<div class="vtd-head">' +
            '<div class="vtd-h1">⊞ All tweaks</div>' +
            '<div class="vtd-sub">142 tweak(s) · <span id="vtdApplied">' + appliedN + '</span> applied</div>' +
          '</div>' +
          '<div class="vtd-bar">' +
            '<span class="vtd-btn go">⚡ Boost now</span>' +
            '<span class="vtd-btn">Scan</span>' +
            '<span class="vtd-btn g">Apply all</span>' +
            '<span class="vtd-btn r">Revert all</span>' +
            '<span class="vtd-btn off">Undo last</span>' +
            '<span class="vtd-chk"><i></i>Restore point first</span>' +
            '<span class="vtd-chk"><i></i>Dry run</span>' +
          '</div>' +
          '<div class="vtd-chips">' +
            '<span class="vtd-chip on">All · <b>142</b></span>' +
            '<span class="vtd-chip">Not applied · <b>21</b></span>' +
            '<span class="vtd-chip">Applied · <b>81</b></span>' +
            '<span class="vtd-sep"></span>' +
            '<span class="vtd-chip on">Any risk · <b>142</b></span>' +
            '<span class="vtd-chip">Low · <b>119</b></span>' +
            '<span class="vtd-chip">Medium · <b>21</b></span>' +
            '<span class="vtd-chip">High · <b>2</b></span>' +
            '<span class="vtd-badge" id="vtdBadge"><span class="d"></span><span id="vtdBadgeT">2 queued</span></span>' +
            '<span class="vtd-applyshown"><span class="vtd-btn g" id="vtdApplyShown">Apply all shown (20)</span>' +
              '<span class="vtd-btn r">Revert all shown (81)</span></span>' +
          '</div>' +
          '<div class="vtd-body">' + cards + '</div>' +
        '</div>' +
      '</div>'
    );
  }

  function card(a, applied) {
    return (
      '<div class="vtd-card' + (applied ? ' on' : '') + '" id="' + a.id + '">' +
        '<div class="vtd-ic">' + a.ic + '</div>' +
        '<div class="vtd-cbody">' +
          '<div class="vtd-ct">' + a.title + '</div>' +
          '<div class="vtd-cd">' + a.desc + '</div>' +
          '<div class="vtd-pills"><span class="vtd-risk ' + (a.risk === "med" ? "med" : "") + '">' +
            a.risk + ' risk</span>' + (a.admin ? '<span class="vtd-admin">ADMIN</span>' : '') + '</div>' +
        '</div>' +
        '<div class="vtd-cright">' +
          '<div class="vtd-stat">' + (applied ? "Applied" : "Not applied") + '</div>' +
          '<div class="vtd-sw"><span class="vtd-knob"></span></div>' +
        '</div>' +
      '</div>'
    );
  }

  var C = {
    c1: { id: "c1", ic: "⚡", title: "Remove startup app delay", risk: "low", admin: false,
          desc: "Launch your startup apps right away instead of after Windows' ~10 second wait." },
    c2: { id: "c2", ic: "⚡", title: "High Performance power plan", risk: "low", admin: true,
          desc: "Stop the CPU from down-clocking to save power. Revert goes back to Balanced." },
    c3: { id: "c3", ic: "⚡", title: "Disable hibernation", risk: "med", admin: true,
          desc: "Turn off hibernation and reclaim disk space equal to your RAM." },
    c4: { id: "c4", ic: "⚡", title: "Ultimate Performance power plan", risk: "low", admin: true,
          desc: "Unlock and switch to the hidden Ultimate Performance plan." },
  };
  function cards(applied) {
    return ["c1", "c2", "c3", "c4"].map(function (k) {
      return card(C[k], applied.indexOf(k) >= 0);
    }).join("");
  }

  // Set one card's switch to progress p (0 off .. 1 on).
  function setSwitch($, id, p) {
    var kn = $("#" + id + " .vtd-knob"), sw = $("#" + id + " .vtd-sw"),
        cd = $("#" + id), st = $("#" + id + " .vtd-stat");
    if (!kn) return;
    kn.style.left = (3 + p * 20) + "px";
    sw.style.background = p > 0.5 ? "rgba(76,195,138," + (0.5 + p * 0.5) + ")" : "#35343f";
    var on = p >= 1;
    cd.classList.toggle("on", on);
    st.textContent = on ? "Applied" : (p > 0.02 && p < 1 ? "Applying…" : "Not applied");
  }
  function setCount($, n) { var e = $("#vtdApplied"); if (e) e.textContent = n; }
  function badge($, show, txt) {
    var b = $("#vtdBadge"); if (!b) return;
    b.style.display = show ? "flex" : "none";
    if (show) $("#vtdBadgeT").textContent = txt;
  }

  var steps = [
    {
      id: "browse", name: "Optimize", dur: 5,
      html: shell(cards(["c1", "c2", "c3"]), 81),
      draw: function (t, $) {
        return { cursor: G(t, [[0, 0, 980, 620], [0.8, 2.4, SW_X, CARD_Y[3]]]) };
      },
    },
    {
      id: "toggle", name: "Toggle a tweak", dur: 5.5,
      html: shell(cards(["c1", "c2", "c3"]), 81),
      draw: function (t, $) {
        var p = E(t, 1.9, 2.6);
        setSwitch($, "c4", p);
        setCount($, p >= 1 ? 82 : 81);
        return { cursor: G(t, [[0, 0, SW_X, CARD_Y[3]], [3.4, 4.6, 900, 470]], [1.75]) };
      },
    },
    {
      id: "apply", name: "Apply all shown", dur: 7,
      html: shell(cards(["c1", "c4"]), 100),
      draw: function (t, $) {
        // Click "Apply all shown" ~1.3 -> c2 then c3 apply, badge counts down.
        setSwitch($, "c2", E(t, 1.6, 2.7));
        setSwitch($, "c3", E(t, 2.7, 3.8));
        var pending = (t >= 1.3 ? 2 : 0) - (t >= 2.7 ? 1 : 0) - (t >= 3.8 ? 1 : 0);
        badge($, t >= 1.3 && t < 4.3, pending + " queued");
        setCount($, 100 + (t >= 2.7 ? 1 : 0) + (t >= 3.8 ? 1 : 0));
        return {
          cursor: G(t, [[0, 0, SW_X, CARD_Y[3]], [0.6, 1.3, APPLY_SHOWN[0], APPLY_SHOWN[1]],
                        [4.4, 5.5, 900, 470]], [1.3]),
        };
      },
    },
  ];

  HTMLDemo.mount(mountEl, {
    steps: steps,
    tabs: ["VoidTweaks"],
    label: "VoidTweaks Optimize view",
  });
})();
