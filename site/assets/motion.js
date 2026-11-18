// VoidTweaks motion — GSAP ScrollTrigger reveals, parallax, count-up, 3D logo tilt.

// Spotlight hover on cards (pure DOM, no GSAP dependency).
(function () {
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  document.addEventListener("pointermove", function (e) {
    var card = e.target.closest && e.target.closest(".card");
    if (!card) return;
    var r = card.getBoundingClientRect();
    card.style.setProperty("--mx", (e.clientX - r.left) + "px");
    card.style.setProperty("--my", (e.clientY - r.top) + "px");
  });
})();

(function () {
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var hasGsap = window.gsap && window.ScrollTrigger;
  if (!hasGsap || reduce) return; // graceful: everything stays visible, no motion

  gsap.registerPlugin(ScrollTrigger);

  // Reveal on scroll
  gsap.utils.toArray(".reveal").forEach(function (el) {
    gsap.set(el, { opacity: 0, y: 30 });
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.9, ease: "power3.out",
      scrollTrigger: { trigger: el, start: "top 88%" }
    });
  });

  // Auto-reveal every child block of a container (guide/faq long-form)
  gsap.utils.toArray("[data-autoreveal]").forEach(function (c) {
    gsap.utils.toArray(c.children).forEach(function (el) {
      gsap.set(el, { opacity: 0, y: 22 });
      gsap.to(el, {
        opacity: 1, y: 0, duration: 0.65, ease: "power3.out",
        scrollTrigger: { trigger: el, start: "top 92%" }
      });
    });
  });

  // Staggered children (feature grids)
  gsap.utils.toArray(".stagger").forEach(function (group) {
    var kids = group.children;
    gsap.set(kids, { opacity: 0, y: 26 });
    gsap.to(kids, {
      opacity: 1, y: 0, duration: 0.7, ease: "power3.out", stagger: 0.08,
      scrollTrigger: { trigger: group, start: "top 82%" }
    });
  });

  // Parallax nebulae
  gsap.utils.toArray("[data-par]").forEach(function (el) {
    var s = parseFloat(el.getAttribute("data-par")) || 0.2;
    gsap.to(el, {
      yPercent: s * 100, ease: "none",
      scrollTrigger: { trigger: document.body, start: "top top", end: "bottom bottom", scrub: true }
    });
  });

  // Feature images subtle parallax
  gsap.utils.toArray(".fimg img").forEach(function (img) {
    gsap.fromTo(img, { yPercent: 8 }, {
      yPercent: -8, ease: "none",
      scrollTrigger: { trigger: img, start: "top bottom", end: "bottom top", scrub: true }
    });
  });

  // Count-up stats
  gsap.utils.toArray("[data-count]").forEach(function (el) {
    var target = parseInt(el.getAttribute("data-count"), 10) || 0;
    var suffix = el.getAttribute("data-suffix") || "";
    var obj = { v: 0 };
    ScrollTrigger.create({
      trigger: el, start: "top 90%", once: true,
      onEnter: function () {
        el.classList.add("counting");
        gsap.to(obj, {
          v: target, duration: 1.4, ease: "power2.out",
          onUpdate: function () { el.textContent = Math.round(obj.v) + suffix; },
          onComplete: function () { el.classList.remove("counting"); }
        });
      }
    });
  });

  // 3D tilt on the hero logo
  var halo = document.getElementById("halo3d");
  if (halo) {
    var img = halo.querySelector(".logo");
    gsap.set(img, { transformPerspective: 700, transformOrigin: "center" });
    var hero = halo.closest("section");
    function onMove(e) {
      var r = hero.getBoundingClientRect();
      var dx = (e.clientX - (r.left + r.width / 2)) / (r.width / 2);
      var dy = (e.clientY - (r.top + r.height / 2)) / (r.height / 2);
      gsap.to(img, { rotationY: dx * 14, rotationX: -dy * 14, duration: 0.5, ease: "power2.out" });
    }
    function onLeave() { gsap.to(img, { rotationX: 0, rotationY: 0, duration: 0.8, ease: "elastic.out(1,0.5)" }); }
    hero.addEventListener("mousemove", onMove);
    hero.addEventListener("mouseleave", onLeave);
  }

  // Scroll-zoom hero: logo gently scales + lifts as you scroll past
  if (halo) {
    gsap.to(halo, {
      scale: 1.14, yPercent: -16, ease: "none",
      scrollTrigger: { trigger: halo.closest("section"), start: "top top", end: "bottom top", scrub: true }
    });
  }

  // Animated section dividers draw in
  gsap.utils.toArray(".divider").forEach(function (d) {
    ScrollTrigger.create({
      trigger: d, start: "top 92%", once: true,
      onEnter: function () { d.classList.add("in"); }
    });
  });
})();

/* ── Pure-DOM interactions (work without GSAP) ── */
(function () {
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce) return;
  var lerp = function (a, b, t) { return a + (b - a) * t; };

  // Shrinking dock nav
  var nav = document.querySelector("header.nav");
  if (nav) {
    var onScroll = function () { nav.classList.toggle("scrolled", window.scrollY > 40); };
    window.addEventListener("scroll", onScroll, { passive: true }); onScroll();
  }

  // Magnetic buttons
  document.querySelectorAll(".btn").forEach(function (btn) {
    btn.addEventListener("pointermove", function (e) {
      var r = btn.getBoundingClientRect();
      var dx = (e.clientX - (r.left + r.width / 2)) / r.width;
      var dy = (e.clientY - (r.top + r.height / 2)) / r.height;
      btn.style.transform = "translate(" + (dx * 14) + "px," + (dy * 10) + "px)";
    });
    btn.addEventListener("pointerleave", function () { btn.style.transform = ""; });
  });

  // 3D tilt on feature screenshots
  document.querySelectorAll(".fimg").forEach(function (box) {
    var img = box.querySelector("img"); if (!img) return;
    box.addEventListener("pointermove", function (e) {
      var r = box.getBoundingClientRect();
      var dx = (e.clientX - (r.left + r.width / 2)) / (r.width / 2);
      var dy = (e.clientY - (r.top + r.height / 2)) / (r.height / 2);
      img.style.transform = "rotateY(" + (dx * 7) + "deg) rotateX(" + (-dy * 7) + "deg) scale(1.02)";
    });
    box.addEventListener("pointerleave", function () { img.style.transform = ""; });
  });

  // Interactive starfield — stars drift away from cursor, ease back
  var stars = Array.prototype.slice.call(document.querySelectorAll("#stars .s"));
  if (stars.length) {
    stars.forEach(function (s) { s.dataset.ox = s.offsetLeft; s.dataset.oy = s.offsetTop; s._tx = 0; s._ty = 0; });
    var mx = -1, my = -1;
    window.addEventListener("pointermove", function (e) { mx = e.clientX; my = e.clientY; }, { passive: true });
    (function raf() {
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i], tx = 0, ty = 0;
        if (mx >= 0) {
          var dx = (+s.dataset.ox) - mx, dy = (+s.dataset.oy) - my;
          var d2 = dx * dx + dy * dy;
          if (d2 < 14000) { var f = (1 - d2 / 14000) * 26, d = Math.sqrt(d2) || 1; tx = dx / d * f; ty = dy / d * f; }
        }
        s._tx = lerp(s._tx, tx, 0.12); s._ty = lerp(s._ty, ty, 0.12);
        s.style.transform = "translate(" + s._tx.toFixed(1) + "px," + s._ty.toFixed(1) + "px)";
      }
      requestAnimationFrame(raf);
    })();
  }

  // Cursor parallax — hero pills & nebulae drift with the mouse
  var floaters = [];
  document.querySelectorAll(".pills .pill").forEach(function (p, i) { floaters.push({ el: p, k: 6 + (i % 3) * 3 }); });
  document.querySelectorAll(".sky .neb").forEach(function (n) { floaters.push({ el: n, k: 20 }); });
  if (floaters.length) {
    window.addEventListener("pointermove", function (e) {
      var cx = (e.clientX / window.innerWidth - 0.5), cy = (e.clientY / window.innerHeight - 0.5);
      floaters.forEach(function (f) { f.el.style.translate = (cx * f.k) + "px " + (cy * f.k) + "px"; });
    }, { passive: true });
  }

  // Text scramble on the hero headline
  var h1 = document.querySelector(".hero h1");
  if (h1 && !h1.dataset.done) {
    h1.dataset.done = "1";
    var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ#%&/<>*01";
    var walk = [];
    (function collect(node) {
      node.childNodes.forEach(function (c) {
        if (c.nodeType === 3) walk.push(c); else if (c.nodeType === 1) collect(c);
      });
    })(h1);
    walk.forEach(function (tn) {
      var full = tn.nodeValue, len = full.length, frame = 0, dur = 26 + len * 2;
      var id = setInterval(function () {
        frame++;
        var out = "";
        for (var i = 0; i < len; i++) {
          if (full[i] === " " || full[i] === " ") { out += full[i]; continue; }
          var reveal = Math.floor((frame / dur) * len);
          out += i < reveal ? full[i] : chars[Math.floor(Math.random() * chars.length)];
        }
        tn.nodeValue = out;
        if (frame >= dur) { tn.nodeValue = full; clearInterval(id); }
      }, 28);
    });
  }
})();
