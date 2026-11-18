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
        gsap.to(obj, {
          v: target, duration: 1.4, ease: "power2.out",
          onUpdate: function () { el.textContent = Math.round(obj.v) + suffix; }
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
})();
