// Rope Escape 95 — desktop shell: windows, taskbar, start menu, boot screen.
(() => {
  'use strict';
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const desktop = $('#desktop');
  const tasks = $('#tasks');
  const startMenu = $('#start-menu');
  const startButton = $('#start-button');
  const phone = () => matchMedia('(max-width: 720px)').matches;
  const wins = new Map();
  let zTop = 10;

  // ---- Game window size: a phone-shaped screen that fits the desktop ----
  function sizeGame() {
    const h = Math.min(760, desktop.clientHeight - 60);
    const w = Math.min(400, Math.round(h * 0.5625), desktop.clientWidth - 40);
    const root = document.documentElement.style;
    root.setProperty('--gw', w + 'px');
    root.setProperty('--gh', Math.round(w / 0.5625) + 'px');
  }

  // ---- Windows ----
  class Win {
    constructor(el) {
      this.el = el;
      this.id = el.dataset.win;
      this.title = el.dataset.title;
      this.task = null;
      this.moved = false;
      el.hidden = true;
      const bar = $('.titlebar', el);
      bar.addEventListener('pointerdown', (e) => this.drag(e));
      bar.addEventListener('dblclick', () => el.querySelector('[data-max]') && this.maximize());
      el.addEventListener('pointerdown', () => this.focus(), true);
      $$('[data-min]', el).forEach((b) => b.addEventListener('click', (e) => { e.stopPropagation(); this.minimize(); }));
      $$('[data-max]', el).forEach((b) => b.addEventListener('click', (e) => { e.stopPropagation(); this.maximize(); }));
      $$('[data-close],[data-close-self]', el).forEach((b) => b.addEventListener('click', (e) => { e.stopPropagation(); this.close(); }));
    }
    get open() { return !this.el.hidden; }
    show() {
      if (!this.open) {
        this.el.hidden = false;
        if (!this.moved) this.place();
        this.addTask();
      }
      this.el.classList.remove('min');
      this.focus();
    }
    place() {
      const el = this.el, dw = desktop.clientWidth, dh = desktop.clientHeight;
      const w = el.offsetWidth, h = el.offsetHeight;
      let x, y;
      if (this.id === 'game') { x = Math.max(110, (dw - w) / 2 - (dw > 1100 ? 120 : 0)); y = Math.max(8, (dh - h) / 2); }
      else if (this.id === 'about') { x = Math.min(dw - w - 12, dw / 2 + 230); y = 40; if (x < 120) { x = (dw - w) / 2; y = 30; } }
      else if (this.id === 'msg') { x = (dw - w) / 2; y = (dh - h) / 2; }
      else { const n = [...wins.values()].filter((o) => o.open).length; x = 140 + n * 24; y = 50 + n * 24; }
      x = Math.max(0, Math.min(x, dw - w)); y = Math.max(0, Math.min(y, dh - 30));
      el.style.left = Math.round(x) + 'px';
      el.style.top = Math.round(y) + 'px';
    }
    focus() {
      wins.forEach((o) => { o.el.classList.remove('focused'); o.task && o.task.classList.remove('active'); });
      this.el.classList.add('focused');
      this.el.style.zIndex = ++zTop;
      this.task && this.task.classList.add('active');
      closeStart();
    }
    minimize() {
      this.el.classList.add('min');
      this.el.classList.remove('focused');
      this.task && this.task.classList.remove('active');
      const next = [...wins.values()].filter((o) => o.open && !o.el.classList.contains('min')).sort((a, b) => b.el.style.zIndex - a.el.style.zIndex)[0];
      next && next.focus();
    }
    maximize() { this.el.classList.toggle('max'); this.focus(); }
    close() {
      this.el.hidden = true;
      this.el.classList.remove('min', 'max');
      this.task && this.task.remove();
      this.task = null;
      const next = [...wins.values()].filter((o) => o.open && !o.el.classList.contains('min')).sort((a, b) => b.el.style.zIndex - a.el.style.zIndex)[0];
      next && next.focus();
    }
    addTask() {
      const b = document.createElement('button');
      b.className = 'btn';
      const icon = $('.caption img, .caption svg', this.el);
      if (icon) b.append(icon.cloneNode(true));
      const span = document.createElement('span');
      span.textContent = this.title;
      b.append(span);
      b.addEventListener('click', () => {
        if (this.el.classList.contains('min') || !this.el.classList.contains('focused')) this.show();
        else this.minimize();
      });
      tasks.append(b);
      this.task = b;
    }
    drag(e) {
      if (e.button !== 0 || e.target.closest('button') || phone() || this.el.classList.contains('max')) return;
      const el = this.el, sx = e.clientX - el.offsetLeft, sy = e.clientY - el.offsetTop;
      const bar = e.currentTarget;
      bar.setPointerCapture(e.pointerId);
      document.body.classList.add('dragging');
      const move = (ev) => {
        const x = Math.max(-el.offsetWidth + 60, Math.min(ev.clientX - sx, desktop.clientWidth - 60));
        const y = Math.max(0, Math.min(ev.clientY - sy, desktop.clientHeight - 24));
        el.style.left = x + 'px';
        el.style.top = y + 'px';
        this.moved = true;
      };
      const up = () => {
        bar.removeEventListener('pointermove', move);
        bar.removeEventListener('pointerup', up);
        bar.removeEventListener('pointercancel', up);
        document.body.classList.remove('dragging');
      };
      bar.addEventListener('pointermove', move);
      bar.addEventListener('pointerup', up);
      bar.addEventListener('pointercancel', up);
    }
  }
  $$('.window').forEach((el) => wins.set(el.dataset.win, new Win(el)));

  function openWin(id) { const w = wins.get(id); w && w.show(); closeStart(); }
  function message(key) {
    const text = {
      android: 'The Android version is still in the works. Play it here in your browser or on iPhone for now.',
    }[key] || key;
    $('#msg-text').textContent = text;
    openWin('msg');
  }

  document.addEventListener('click', (e) => {
    const o = e.target.closest('[data-open]');
    if (o) { e.preventDefault(); openWin(o.dataset.open); return; }
    const m = e.target.closest('[data-msg]');
    if (m) { e.preventDefault(); message(m.dataset.msg); }
  });

  // ---- Shortcuts: single click selects, double click (or Enter) opens ----
  $$('.shortcut').forEach((s) => {
    s.addEventListener('click', (e) => {
      if (phone() || e.detail >= 2 || e.detail === 0) return; // open on dblclick / keyboard
      e.preventDefault();
      e.stopImmediatePropagation();
      $$('.shortcut').forEach((o) => o.classList.toggle('selected', o === s));
    }, true);
    s.addEventListener('dblclick', () => { s.classList.remove('selected'); if (s.dataset.open) openWin(s.dataset.open); else if (s.href) window.open(s.href, '_blank', 'noopener'); });
  });
  desktop.addEventListener('pointerdown', (e) => {
    if (e.target === desktop || e.target.id === 'shortcuts') { $$('.shortcut.selected').forEach((o) => o.classList.remove('selected')); closeStart(); }
  });

  // ---- Start menu ----
  function closeStart() { startMenu.hidden = true; startButton.classList.remove('active'); startButton.setAttribute('aria-expanded', 'false'); }
  startButton.addEventListener('click', (e) => {
    e.stopPropagation();
    const open = startMenu.hidden;
    startMenu.hidden = !open;
    startButton.classList.toggle('active', open);
    startButton.setAttribute('aria-expanded', String(open));
    if (open) $('button, a', startMenu).focus();
  });
  document.addEventListener('pointerdown', (e) => { if (!e.target.closest('#start-menu, #start-button')) closeStart(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !startMenu.hidden) { closeStart(); startButton.focus(); } });
  $('#reset-desktop').addEventListener('click', () => {
    wins.forEach((w) => { w.moved = false; w.el.classList.remove('max'); if (w.open) w.place(); });
    closeStart();
  });

  // ---- Clock ----
  function tick() {
    const d = new Date();
    $('#clock').textContent = d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
    $('#clock').dateTime = d.toISOString();
  }
  tick();
  setInterval(tick, 15000);

  // ---- Layout + boot ----
  sizeGame();
  addEventListener('resize', () => {
    sizeGame();
    wins.forEach((w) => { if (w.open && !w.moved) w.place(); });
  });

  function start() {
    openWin('game');
    if (!phone()) openWin('about');
    wins.get('game').focus();
    const open = new URLSearchParams(location.search).get('open');
    if (open && wins.has(open)) openWin(open);
  }
  const boot = $('#boot');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  let booted = false;
  function finishBoot() {
    if (booted) return;
    booted = true;
    boot.classList.add('done');
    setTimeout(() => boot.remove(), 350);
    start();
  }
  if (reduce || sessionStorage.getItem('booted')) { boot.remove(); booted = true; start(); }
  else { boot.addEventListener('click', finishBoot); setTimeout(finishBoot, 1700); }
  try { sessionStorage.setItem('booted', '1'); } catch (_) {}
})();
