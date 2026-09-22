// Overlay layer: one translucent "ghost" per scored control showing the planned
// value and a confidence halo. Clicking a ghost asks the host to apply it.
(function () {
  if (window.__ghost) { return; }
  const style = document.createElement('style');
  style.textContent = `
    .fg-ghost { position: absolute; z-index: 2147483000; pointer-events: none; border-radius: 7px;
      transition: opacity .25s ease, transform .25s ease; opacity: 0; transform: scale(.97); }
    .fg-ghost.on { opacity: 1; transform: none; }
    .fg-ghost .fg-halo { position: absolute; inset: -3px; border-radius: 8px; border: 2px solid var(--c);
      box-shadow: 0 0 0 4px color-mix(in srgb, var(--c) 22%, transparent), 0 0 18px color-mix(in srgb, var(--c) 45%, transparent); }
    .fg-ghost .fg-text { position: absolute; left: 10px; right: 10px; top: 50%; transform: translateY(-50%);
      font: italic 14px -apple-system, sans-serif; color: color-mix(in srgb, var(--c) 70%, #333); opacity: .75;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .fg-ghost .fg-tag { position: absolute; right: -2px; top: -20px; pointer-events: auto; cursor: pointer;
      font: 600 10px ui-monospace, Menlo, monospace; color: #fff; background: var(--c); padding: 2px 6px; border-radius: 4px; white-space: nowrap; }
    .fg-ghost.done .fg-text { display: none; }
    .fg-ghost.done .fg-halo { border-style: dashed; box-shadow: none; }
    .fg-ghost.scanning .fg-halo { border-color: #ff6a00; animation: fg-pulse .5s ease-in-out infinite alternate; }
    @keyframes fg-pulse { from { opacity: .4 } to { opacity: 1 } }`;
  document.head.appendChild(style);
  const layer = document.createElement('div');
  layer.style.cssText = 'position:absolute;left:0;top:0;width:0;height:0;';
  document.body.appendChild(layer);
  const byToken = (t) => document.querySelector('[data-cua-token="' + t + '"]');
  const ghosts = new Map();
  const place = (g, el) => {
    const r = el.getBoundingClientRect();
    Object.assign(g.style, { left: (r.left + scrollX) + 'px', top: (r.top + scrollY) + 'px', width: r.width + 'px', height: r.height + 'px' });
  };
  const relayout = () => ghosts.forEach((g, t) => { const el = byToken(t); if (el) { place(g, el); } });
  addEventListener('resize', relayout);
  window.__ghost = {
    scanning(token) {
      const el = byToken(token); if (!el) { return false; }
      let g = ghosts.get(token);
      if (!g) {
        g = document.createElement('div'); g.className = 'fg-ghost';
        g.innerHTML = '<div class="fg-halo"></div><div class="fg-text"></div><div class="fg-tag"></div>';
        g.querySelector('.fg-tag').addEventListener('click', () =>
          window.webkit.messageHandlers.ghost.postMessage(token));
        layer.appendChild(g); ghosts.set(token, g);
      }
      place(g, el); g.classList.add('scanning');
      requestAnimationFrame(() => g.classList.add('on'));
      el.scrollIntoView({ block: 'nearest' });
      return true;
    },
    show(token, text, tag, color, isCheckbox) {
      const g = ghosts.get(token); if (!g) { return false; }
      g.classList.remove('scanning');
      g.style.setProperty('--c', color);
      g.querySelector('.fg-text').textContent = isCheckbox ? '' : text;
      g.querySelector('.fg-tag').textContent = tag;
      return true;
    },
    done(token) { const g = ghosts.get(token); if (g) { g.classList.add('done'); } return true; },
    clear() { ghosts.forEach((g) => g.remove()); ghosts.clear(); return true; },
    reset() {
      this.clear();
      document.querySelectorAll('input, select, textarea').forEach((el) => {
        if (el.type === 'checkbox') { el.checked = false; } else { el.value = ''; }
      });
      scrollTo(0, 0); return true;
    },
  };
})();
