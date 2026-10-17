(function () {
  var doc = document.documentElement;
  var body = document.body;
  var root = body.getAttribute("data-root") || "";
  var indexFile = body.getAttribute("data-index") || "";

  var themeBtn = document.querySelector(".theme-btn");
  if (themeBtn) {
    themeBtn.addEventListener("click", function () {
      var current = doc.getAttribute("data-theme");
      if (!current) current = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
      var next = current === "dark" ? "light" : "dark";
      doc.setAttribute("data-theme", next);
      try { localStorage.setItem("noteic-theme", next); } catch (e) {}
    });
  }

  var toggle = document.getElementById("nav-toggle");
  document.querySelectorAll(".side a").forEach(function (a) {
    a.addEventListener("click", function () { if (toggle) toggle.checked = false; });
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && toggle && toggle.checked) toggle.checked = false;
  });

  var toc = document.querySelectorAll(".toc a");
  if (toc.length && "IntersectionObserver" in window) {
    var heads = [];
    toc.forEach(function (a) {
      var h = document.getElementById(decodeURIComponent(a.getAttribute("href").slice(1)));
      if (h) heads.push({ h: h, a: a });
    });
    var mark = function () {
      var y = window.scrollY + 90, on = heads[0];
      heads.forEach(function (x) { if (x.h.offsetTop <= y) on = x; });
      toc.forEach(function (a) { a.classList.remove("on"); });
      if (on) on.a.classList.add("on");
    };
    window.addEventListener("scroll", mark, { passive: true });
    mark();
  }

  var still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var reveals = document.querySelectorAll(".reveal, .hero-shot");
  if (!("IntersectionObserver" in window) || still) {
    reveals.forEach(function (el) { el.classList.add("is-in"); });
  } else {
    var seen = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add("is-in"); seen.unobserve(en.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
    reveals.forEach(function (el) { seen.observe(el); });
  }

  var teaser = document.querySelector("video[data-autoplay]");
  if (teaser) {
    var sparen = navigator.connection && navigator.connection.saveData;
    var breit = window.matchMedia("(min-width: 45rem)").matches;
    if (still || sparen || !breit || !("IntersectionObserver" in window)) {
      teaser.setAttribute("controls", "");
    } else {
      teaser.muted = true;
      new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
          if (en.isIntersecting) { teaser.play().catch(function () { teaser.setAttribute("controls", ""); }); }
          else { teaser.pause(); }
        });
      }, { threshold: 0.35 }).observe(teaser);
    }
  }

  var box = document.querySelector(".search");
  if (!box) return;
  var input = box.querySelector("input");
  var results = box.querySelector(".search-results");
  var button = box.querySelector(".search-btn");
  var data = null, loading = false, picked = -1;

  function load(then) {
    if (data) { then(); return; }
    if (loading) return;
    loading = true;
    var s = document.createElement("script");
    s.src = root + "assets/search-index.js";
    s.onload = function () { data = window.NOTEIC_INDEX || []; then(); };
    document.head.appendChild(s);
  }

  function esc(s) {
    return s.replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; });
  }

  function words(q) {
    return q.toLowerCase().split(/\s+/).filter(function (w) { return w.length > 0; });
  }

  function highlight(text, ws) {
    var out = esc(text);
    ws.forEach(function (w) {
      var re = new RegExp("(" + w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "ig");
      out = out.replace(re, "<mark>$1</mark>");
    });
    return out;
  }

  function snippet(text, ws) {
    var low = text.toLowerCase(), at = -1;
    ws.forEach(function (w) { var i = low.indexOf(w); if (i >= 0 && (at < 0 || i < at)) at = i; });
    if (at < 0) return text.slice(0, 120) + (text.length > 120 ? "…" : "");
    var start = Math.max(0, at - 40);
    var part = text.slice(start, start + 140);
    return (start > 0 ? "…" : "") + part + (start + 140 < text.length ? "…" : "");
  }

  function score(entry, ws) {
    var t = entry.t.toLowerCase(), h = entry.h.toLowerCase(), x = entry.x.toLowerCase(), s = 0;
    for (var i = 0; i < ws.length; i++) {
      var w = ws[i], hit = false;
      if (t.indexOf(w) >= 0) { s += 6; hit = true; }
      if (h.indexOf(w) >= 0) { s += 4; hit = true; }
      if (x.indexOf(w) >= 0) { s += 1; hit = true; }
      if (!hit) return 0;
    }
    if (!entry.h) s += 1;
    return s;
  }

  function render() {
    var ws = words(input.value);
    picked = -1;
    if (!ws.length) { results.innerHTML = ""; results.classList.remove("has"); return; }
    var found = data.map(function (e) { return { e: e, s: score(e, ws) }; })
      .filter(function (r) { return r.s > 0; })
      .sort(function (a, b) { return b.s - a.s; })
      .slice(0, 12);
    if (!found.length) {
      results.innerHTML = '<div class="r-none">No results for “' + esc(input.value.trim()) + '”</div>';
    } else {
      results.innerHTML = found.map(function (r) {
        var e = r.e;
        var href = root + (e.u ? e.u + "/" : "") + indexFile + (e.a ? "#" + e.a : "");
        return '<a role="option" href="' + href + '"><div class="r-title">' + highlight(e.h || e.t, ws) + "</div>" +
          (e.h ? '<div class="r-where">' + esc(e.t) + "</div>" : "") +
          '<div class="r-text">' + highlight(snippet(e.x, ws), ws) + "</div></a>";
      }).join("");
    }
    results.classList.add("has");
  }

  function open() { box.classList.add("open"); load(render); }
  function close() { box.classList.remove("open"); }

  input.addEventListener("focus", open);
  input.addEventListener("input", function () { load(render); });
  input.addEventListener("keydown", function (e) {
    var items = results.querySelectorAll("a");
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      if (!items.length) return;
      e.preventDefault();
      picked = (picked + (e.key === "ArrowDown" ? 1 : -1) + items.length) % items.length;
      items.forEach(function (a, i) { a.classList.toggle("on", i === picked); });
      items[picked].scrollIntoView({ block: "nearest" });
    } else if (e.key === "Enter") {
      var a = items[picked >= 0 ? picked : 0];
      if (a) { e.preventDefault(); window.location.href = a.getAttribute("href"); }
    } else if (e.key === "Escape") {
      input.blur(); close();
    }
  });
  if (button) button.addEventListener("click", function () { box.classList.add("open"); input.focus(); });
  document.addEventListener("click", function (e) { if (!box.contains(e.target)) close(); });
  document.addEventListener("keydown", function (e) {
    if (e.key === "/" && document.activeElement !== input && !/input|textarea/i.test(document.activeElement.tagName)) {
      e.preventDefault(); input.focus();
    }
  });
})();
