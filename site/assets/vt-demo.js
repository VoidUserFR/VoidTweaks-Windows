/* Live VoidTweaks demo window (html-demo engine, vanilla).
   Recreates the Optimize view at 1200x750 and plays it step by step:
   browse -> toggle a tweak -> queue several at once. */
(function () {
  var mountEl = document.getElementById("vt-demo");
  if (!mountEl || !window.HTMLDemo) return;
  var E = HTMLDemo.ease, G = HTMLDemo.glide;

  // Toggle switch centres in stage coords (where the pointer aims).
  var T1 = [690, 150], T2 = [1150, 150], T3 = [690, 322];

  // ── shared UI (one <style> + the three-pane Optimize view) ──
  function shell(cards) {
    return (
      '<style>' +
      '.vtd{position:absolute;inset:0;display:flex;background:#0a0812;color:#c7c3dc;font-weight:500}' +
      '.vtd-rail{width:66px;flex:none;background:#0d0b16;border-right:1px solid rgba(255,255,255,.06);' +
        'display:flex;flex-direction:column;align-items:center;gap:6px;padding:16px 0}' +
      '.vtd-rail .r{width:40px;height:40px;border-radius:11px;display:grid;place-items:center;font-size:19px;opacity:.5}' +
      '.vtd-rail .r.on{opacity:1;background:rgba(139,124,240,.18);box-shadow:inset 0 0 0 1px rgba(139,124,240,.4)}' +
      '.vtd-cat{width:224px;flex:none;background:#0b0914;border-right:1px solid rgba(255,255,255,.06);padding:20px 14px}' +
      '.vtd-cat h3{font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#7b7790;margin:0 8px 12px}' +
      '.vtd-cat a{display:flex;justify-content:space-between;padding:9px 12px;border-radius:9px;font-size:14px;color:#9a97ad}' +
      '.vtd-cat a .n{color:#615e75;font-size:12px}' +
      '.vtd-cat a.on{background:rgba(139,124,240,.16);color:#fff}' +
      '.vtd-main{flex:1;min-width:0;display:flex;flex-direction:column}' +
      '.vtd-top{height:60px;flex:none;display:flex;align-items:center;gap:10px;padding:0 24px;' +
        'border-bottom:1px solid rgba(255,255,255,.06);background:#0b0914}' +
      '.vtd-btn{padding:8px 14px;border-radius:9px;font-size:13px;font-weight:700;color:#d7d3ea;' +
        'background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.09)}' +
      '.vtd-btn.p{color:#0a0a0c;background:linear-gradient(180deg,#fff,#ddd9ea);border-color:transparent}' +
      '.vtd-chk{display:flex;align-items:center;gap:7px;font-size:12.5px;color:#9a97ad;margin-left:4px}' +
      '.vtd-chk i{width:16px;height:16px;border-radius:5px;background:#8b7cf0;display:inline-block;position:relative}' +
      '.vtd-chk i:after{content:"";position:absolute;left:5px;top:2px;width:4px;height:8px;border:2px solid #0a0812;' +
        'border-top:0;border-left:0;transform:rotate(42deg)}' +
      '.vtd-badge{margin-left:auto;display:flex;align-items:center;gap:7px;padding:7px 13px;border-radius:999px;' +
        'font-size:13px;font-weight:700;color:#fff;background:rgba(139,124,240,.9);opacity:0;transform:scale(.8);' +
        'box-shadow:0 6px 20px rgba(139,124,240,.45)}' +
      '.vtd-badge .d{width:8px;height:8px;border-radius:50%;background:#fff;animation:vtdp 1s ease-in-out infinite}' +
      '@keyframes vtdp{50%{opacity:.4}}' +
      '.vtd-body{flex:1;padding:22px 24px;display:grid;grid-template-columns:1fr 1fr;gap:18px;align-content:start}' +
      '.vtd-card{position:relative;background:rgba(255,255,255,.035);border:1px solid rgba(255,255,255,.1);' +
        'border-radius:14px;padding:18px 20px}' +
      '.vtd-card.on{border-color:rgba(76,195,138,.55);background:rgba(76,195,138,.07)}' +
      '.vtd-card h4{margin:0 0 6px;font-size:16px;font-weight:700;color:#f3f2f8;padding-right:60px}' +
      '.vtd-card p{margin:0;font-size:13px;color:#9a97ad;line-height:1.45}' +
      '.vtd-meta{margin-top:14px;display:flex;align-items:center;gap:10px}' +
      '.vtd-risk{font-size:11px;font-weight:700;letter-spacing:.5px;text-transform:uppercase;padding:3px 9px;' +
        'border-radius:999px;background:rgba(76,195,138,.16);color:#6fd6a0}' +
      '.vtd-risk.med{background:rgba(239,179,108,.16);color:#f0bd7a}' +
      '.vtd-status{font-size:12.5px;color:#75728a}' +
      '.vtd-card.on .vtd-status{color:#6fd6a0;font-weight:700}' +
      '.vtd-sw{position:absolute;top:18px;right:20px;width:48px;height:27px;border-radius:999px;background:#35343f}' +
      '.vtd-knob{position:absolute;top:3px;left:3px;width:21px;height:21px;border-radius:50%;background:#fff;' +
        'box-shadow:0 2px 5px rgba(0,0,0,.4)}' +
      '</style>' +
      '<div class="vtd">' +
        '<div class="vtd-rail">' +
          '<div class="r">◉</div><div class="r on">⚡</div><div class="r">🧰</div>' +
          '<div class="r">🔧</div><div class="r">⚙️</div>' +
        '</div>' +
        '<div class="vtd-cat"><h3>Optimize</h3>' +
          '<a class="on">All <span class="n">142</span></a>' +
          '<a>Favorites <span class="n">8</span></a>' +
          '<a>Performance <span class="n">24</span></a>' +
          '<a>Gaming <span class="n">17</span></a>' +
          '<a>Privacy <span class="n">21</span></a>' +
          '<a>Network <span class="n">15</span></a>' +
          '<a>Visual <span class="n">12</span></a>' +
        '</div>' +
        '<div class="vtd-main">' +
          '<div class="vtd-top">' +
            '<span class="vtd-btn p">⚡ Boost</span>' +
            '<span class="vtd-btn">Scan</span>' +
            '<span class="vtd-btn">Apply all</span>' +
            '<span class="vtd-btn">Undo last</span>' +
            '<span class="vtd-chk"><i></i>Restore point first</span>' +
            '<span class="vtd-badge" id="vtdBadge"><span class="d"></span><span id="vtdBadgeT">1 queued</span></span>' +
          '</div>' +
          '<div class="vtd-body">' + cards + '</div>' +
        '</div>' +
      '</div>'
    );
  }

  function card(id, title, desc, risk, applied) {
    return (
      '<div class="vtd-card' + (applied ? ' on' : '') + '" id="' + id + '">' +
        '<div class="vtd-sw"><span class="vtd-knob"></span></div>' +
        '<h4>' + title + '</h4><p>' + desc + '</p>' +
        '<div class="vtd-meta"><span class="vtd-risk ' + (risk === "med" ? "med" : "") + '">' + risk + ' risk</span>' +
        '<span class="vtd-status">' + (applied ? "Applied" : "Not applied") + '</span></div>' +
      '</div>'
    );
  }

  var C = {
    c1: ["c1", "Ultimate Performance plan", "Unlock the hidden maximum-performance Windows power plan.", "low"],
    c2: ["c2", "Disable telemetry", "Stop Windows uploading diagnostic &amp; usage data.", "low"],
    c3: ["c3", "Game Mode + GPU priority", "Prioritise the foreground game for CPU &amp; GPU.", "low"],
    c4: ["c4", "Trim startup delay", "Remove the 10-second delay before startup apps run.", "med"],
  };
  function cards(applied) {
    return ["c1", "c2", "c3", "c4"].map(function (k) {
      var a = C[k];
      return card(a[0], a[1], a[2], a[3], applied.indexOf(k) >= 0);
    }).join("");
  }

  // Set one card's switch to a progress p (0 off .. 1 on).
  function setSwitch($, id, p) {
    var kn = $("#" + id + " .vtd-knob"), sw = $("#" + id + " .vtd-sw"),
        cd = $("#" + id), st = $("#" + id + " .vtd-status");
    if (!kn) return;
    kn.style.left = (3 + p * 21) + "px";
    sw.style.background = p > 0.5
      ? "rgba(76,195,138," + (0.5 + p * 0.5) + ")"
      : "#35343f";
    var on = p >= 1;
    cd.classList.toggle("on", on);
    st.textContent = on ? "Applied" : (p > 0.02 && p < 1 ? "Applying…" : "Not applied");
  }
  function badge($, show, txt) {
    var b = $("#vtdBadge");
    b.style.opacity = show ? "1" : "0";
    b.style.transform = show ? "scale(1)" : "scale(.8)";
    b.style.transition = "opacity .25s, transform .25s";
    if (show) $("#vtdBadgeT").textContent = txt;
  }

  var steps = [
    {
      id: "browse", name: "Optimize", dur: 5,
      html: shell(cards([])),
      draw: function (t, $) {
        return { cursor: G(t, [[0, 0, 900, 640], [0.8, 2.2, T1[0], T1[1]]]) };
      },
    },
    {
      id: "toggle", name: "Toggle a tweak", dur: 5.5,
      html: shell(cards([])),
      draw: function (t, $) {
        setSwitch($, "c1", E(t, 1.9, 2.5));
        return { cursor: G(t, [[0, 0, T1[0], T1[1]], [3.2, 4.4, 820, 470]], [1.85]) };
      },
    },
    {
      id: "queue", name: "Queue several", dur: 7,
      html: shell(cards(["c1"])),
      draw: function (t, $) {
        // c2 clicked ~1.4, c3 clicked ~2.3 — both queue, then apply in turn.
        setSwitch($, "c2", E(t, 1.5, 3.0));
        setSwitch($, "c3", E(t, 3.0, 4.3));
        var pending = (t >= 1.4 ? 1 : 0) + (t >= 2.3 ? 1 : 0)
          - (t >= 3.0 ? 1 : 0) - (t >= 4.3 ? 1 : 0);
        badge($, t >= 1.4 && t < 4.5, pending + " queued");
        var c = G(t, [[0, 0, T1[0], T1[1]], [0.5, 1.4, T2[0], T2[1]], [1.7, 2.3, T3[0], T3[1]],
                      [4.6, 5.6, 840, 500]], [1.4, 2.3]);
        return { cursor: c };
      },
    },
  ];

  HTMLDemo.mount(mountEl, {
    steps: steps,
    tabs: ["VoidTweaks"],
    label: "VoidTweaks Optimize view",
  });
})();
