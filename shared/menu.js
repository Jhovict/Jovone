/* =====================================================================
   JOVONE GAMES — menu de abertura compartilhado
   Tela de título ("aperte para começar"), menu principal com os modos
   e galeria de troféus. Cada jogo chama JovoneFront.init({...}).
   Teclado (setas, Enter, Esc), toque, mouse e controle (direcional, A, B).
   ===================================================================== */
(function(){
  'use strict';
  const CSS = `
.jf{position:absolute;inset:0;z-index:40;font-family:var(--body,"Chakra Petch","Segoe UI",system-ui,sans-serif);color:#e9edf3;-webkit-user-select:none;user-select:none}
.jf[hidden]{display:none!important}
.jf-s{position:absolute;inset:0;display:flex;padding:16px;overflow:auto}
.jf-s[hidden]{display:none!important}
.jf-title{flex-direction:column;align-items:center;justify-content:center;gap:28px;cursor:pointer;background:radial-gradient(ellipse at 50% 55%,rgba(9,13,21,.35),rgba(9,13,21,.88))}
.jf-logo{text-align:center;display:flex;flex-direction:column;align-items:center;gap:8px}
.jf-logo small{letter-spacing:.3em;font-size:.7rem;color:#c7cfdc;font-weight:700;text-transform:uppercase}
.jf-logo b{font-family:var(--display,"Bungee","Impact",sans-serif);font-weight:400;font-size:clamp(2.6rem,10vw,6.4rem);line-height:.88;text-shadow:0 6px 0 rgba(0,0,0,.45),0 0 40px var(--jf-glow);transform:skewX(-8deg)}
.jf-logo b span{display:block;color:var(--jf-accent)}
.jf-logo em{font-style:normal;font-size:.78rem;letter-spacing:.22em;text-transform:uppercase;color:#c7cfdc;max-width:90vw}
.jf-press{border:0;background:rgba(13,20,32,.78);color:#e9edf3;font:700 .9rem var(--body,sans-serif);letter-spacing:.24em;text-transform:uppercase;padding:12px 26px;border-radius:999px;cursor:pointer;animation:jfBlink 1.4s ease-in-out infinite;box-shadow:inset 0 0 0 2px var(--jf-accent)}
@keyframes jfBlink{50%{opacity:.35}}
.jf-ver{position:absolute;bottom:12px;right:16px;font-size:.7rem;color:#8c98ad}
.jf-hub{flex-direction:column;align-items:flex-start;justify-content:center;gap:12px;padding:16px 24px;background:linear-gradient(90deg,rgba(9,13,21,.92) 0%,rgba(9,13,21,.6) 50%,rgba(9,13,21,.15) 85%)}
.jf-hub h1{font-family:var(--display,"Bungee",sans-serif);font-weight:400;margin:0;font-size:2rem;line-height:1}.jf-hub h1 span{color:var(--jf-accent)}
.jf-chips{display:flex;gap:6px;flex-wrap:wrap}
.jf-chip{background:rgba(42,51,70,.9);border-radius:999px;padding:3px 10px;font-size:.74rem;font-weight:600}
.jf-tiles{display:flex;flex-direction:column;gap:8px;width:min(410px,100%)}
.jf-tile{display:grid;grid-template-columns:44px 1fr;column-gap:12px;align-items:center;text-align:left;border:0;border-radius:14px;padding:10px 14px;background:rgba(27,34,48,.94);color:#e9edf3;cursor:pointer;box-shadow:inset 0 0 0 1px rgba(233,237,243,.08);transition:transform .12s,background .12s;font-family:inherit}
.jf-tile i{grid-row:1/3;font-style:normal;font-size:1.7rem;text-align:center}
.jf-tile b{font-family:var(--display,"Bungee",sans-serif);font-weight:400;font-size:1.05rem}
.jf-tile small{color:#8c98ad;font-size:.74rem}
.jf-tile:hover,.jf-tile:focus-visible,.jf-tile:focus{background:var(--jf-accent);color:#0d1420;outline:none;transform:translateX(6px)}
.jf-tile:hover small,.jf-tile:focus small{color:rgba(13,20,32,.75)}
.jf-tile.big{padding:14px}.jf-tile.big b{font-size:1.3rem}
.jf-tile[disabled]{opacity:.45;cursor:default;transform:none}
.jf-row{display:flex;gap:8px}.jf-tile.sm{flex:1;display:block;text-align:center;padding:9px}.jf-tile.sm b{font-size:.8rem}
.jf-tro{align-items:center;justify-content:center;background:rgba(9,13,21,.8)}
.jf-card{background:#1b2230;border-radius:16px;padding:18px 20px;width:min(680px,100%);max-height:100%;overflow:auto;box-shadow:0 20px 60px rgba(0,0,0,.55)}
.jf-card h2{font-family:var(--display,"Bungee",sans-serif);font-weight:400;margin:0 0 4px;font-size:1.5rem}.jf-card h2 span{color:var(--jf-accent)}
.jf-card h3{font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;color:#8c98ad;margin:14px 0 6px}
.jf-kick{font-size:.7rem;letter-spacing:.2em;text-transform:uppercase;color:var(--jf-accent);font-weight:700}
.jf-back{border:0;background:none;color:#8c98ad;font:700 .74rem var(--body,sans-serif);letter-spacing:.1em;text-transform:uppercase;cursor:pointer;padding:0 0 8px;display:block}
.jf-back:hover,.jf-back:focus{color:var(--jf-accent);outline:none}
.jf-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(128px,1fr));gap:8px;margin-top:8px}
.jf-t{background:#2a3346;border-radius:12px;padding:10px 8px;text-align:center;display:flex;flex-direction:column;gap:3px;align-items:center}
.jf-t i{font-style:normal;font-size:2.1rem;line-height:1.1}
.jf-t b{font-size:.76rem;line-height:1.2}.jf-t small{font-size:.66rem;color:#8c98ad;line-height:1.3}
.jf-t.off{opacity:.42}.jf-t.off i{filter:grayscale(1)}
.jf-t.on{box-shadow:inset 0 0 0 2px var(--jf-accent);background:linear-gradient(180deg,var(--jf-soft),#2a3346)}
.jf-recs{display:grid;grid-template-columns:1fr 1fr;gap:3px 14px;font-size:.8rem}
.jf-recs div{display:flex;justify-content:space-between;gap:8px;border-bottom:1px solid rgba(233,237,243,.07);padding:3px 0}
.jf-recs b{font-variant-numeric:tabular-nums;color:var(--jf-accent)}
.jf-backbar{display:block;margin:0 0 6px}
@media (max-width:620px){.jf-recs{grid-template-columns:1fr}.jf-hub{background:rgba(9,13,21,.78)}}
@media (max-height:520px){.jf-tiles{gap:5px}.jf-tile{padding:6px 12px}.jf-tile small{display:none}.jf-hub h1{font-size:1.4rem}.jf-logo b{font-size:clamp(2.2rem,9vw,4rem)}}
`;
  const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;'}[c]));
  const hexA = (hex, a) => { const h = hex.replace('#', ''), n = parseInt(h.length === 3 ? h.replace(/./g, '$&$&') : h, 16); return `rgba(${n >> 16 & 255},${n >> 8 & 255},${n & 255},${a})`; };
  const F = {active:false, cfg:null, el:null, screen:null, started:false};
  let padPrev = {};
  function el(tag, cls, html){ const e = document.createElement(tag); if(cls) e.className = cls; if(html != null) e.innerHTML = html; return e; }
  F.init = function(cfg){
    F.cfg = cfg;
    if(!document.getElementById('jf-css')){ const st = el('style'); st.id = 'jf-css'; st.textContent = CSS; document.head.appendChild(st); }
    const root = F.el = el('div', 'jf'); root.style.setProperty('--jf-accent', cfg.accent || '#f2b632'); root.style.setProperty('--jf-glow', hexA(cfg.accent || '#f2b632', .35)); root.style.setProperty('--jf-soft', hexA(cfg.accent || '#f2b632', .18));
    root.innerHTML = `
      <section class="jf-s jf-title" data-s="title">
        <div class="jf-logo"><small>Jovone Games apresenta</small><b>${esc(cfg.title)}<span>${esc(cfg.title2 || '')}</span></b><em>${esc(cfg.tagline || '')}</em></div>
        <button class="jf-press" type="button">${TOUCHY() ? 'Toque para começar' : 'Aperte para começar'}</button>
        <div class="jf-ver">${esc(cfg.version || '')}</div>
      </section>
      <section class="jf-s jf-hub" data-s="hub" hidden>
        <h1>${esc(cfg.title)} <span>${esc(cfg.title2 || '')}</span></h1>
        <div class="jf-chips" data-r="stats"></div>
        <div class="jf-tiles" data-r="tiles"></div>
      </section>
      <section class="jf-s jf-tro" data-s="trophies" hidden>
        <div class="jf-card">
          <button class="jf-back" type="button" data-back>‹ Voltar</button>
          <div class="jf-kick">Galeria</div><h2>TRO<span>FÉUS</span></h2>
          <div class="jf-chips" data-r="tstats"></div>
          <div class="jf-grid" data-r="grid"></div>
          <div data-r="recs"></div>
        </div>
      </section>`;
    (cfg.root || document.body).appendChild(root);
    root.querySelector('[data-s=title]').addEventListener('click', start);
    root.addEventListener('click', e => { if(e.target.closest('[data-back]')) F.show('hub'); });
    addEventListener('keydown', onKey, true);
    addEventListener('keyup', e => { if(F.active) e.stopImmediatePropagation(); }, true);
    requestAnimationFrame(pollPad);
    let first = true; try{ first = !sessionStorage.getItem('jf_' + (cfg.id || cfg.title)); }catch(e){}
    if(cfg.startHidden) { F.started = true; return F; }
    F.show(first ? 'title' : 'hub');
    if(!first){ F.started = true; }
    return F;
  };
  const TOUCHY = () => (matchMedia && matchMedia('(pointer:coarse)').matches);
  function start(){
    if(F.screen !== 'title') return;
    try{ sessionStorage.setItem('jf_' + (F.cfg.id || F.cfg.title), '1'); }catch(e){}
    F.show('hub');
    if(!F.started){ F.started = true; F.cfg.onStart && F.cfg.onStart(); }
  }
  F.show = function(name){
    const c = F.cfg; F.active = true; F.el.hidden = false; F.screen = name;
    for(const e of (c.cover || [])) if(e) e.style.visibility = 'hidden';
    c.onShow && c.onShow(name);
    for(const s of F.el.querySelectorAll('.jf-s')) s.hidden = s.dataset.s !== name;
    if(name === 'hub'){
      const tiles = c.tiles();
      F.el.querySelector('[data-r=stats]').innerHTML = (c.stats ? c.stats() : []).map(t => `<span class="jf-chip">${esc(t)}</span>`).join('');
      const box = F.el.querySelector('[data-r=tiles]'); box.innerHTML = '';
      const small = tiles.filter(t => t.small), main = tiles.filter(t => !t.small);
      const mk = t => { const b = el('button', 'jf-tile' + (t.big ? ' big' : '') + (t.small ? ' sm' : ''), (t.small ? '' : `<i>${t.icon || ''}</i>`) + `<b>${esc(t.name)}</b>` + (t.desc && !t.small ? `<small>${esc(t.desc)}</small>` : '')); b.type = 'button'; if(t.disabled) b.disabled = true;
        b.addEventListener('click', () => { if(t.trophies){ F.show('trophies'); return; } F.hide(); t.go && t.go(); }); return b; };
      main.forEach(t => box.appendChild(mk(t)));
      if(small.length){ const row = el('div', 'jf-row'); small.forEach(t => row.appendChild(mk(t))); box.appendChild(row); }
      focusFirst();
    } else if(name === 'trophies'){
      const T = c.trophies ? c.trophies() : [], got = T.filter(t => t.got).length;
      F.el.querySelector('[data-r=tstats]').innerHTML = [`🏆 ${got}/${T.length} conquistados`].concat(c.stats ? c.stats() : []).map(t => `<span class="jf-chip">${esc(t)}</span>`).join('');
      F.el.querySelector('[data-r=grid]').innerHTML = T.map(t => `<div class="jf-t ${t.got ? 'on' : 'off'}"><i>${t.got ? t.icon : '🔒'}</i><b>${esc(t.name)}</b><small>${esc(t.desc || '')}${t.prog ? ' · ' + esc(t.prog) : ''}</small></div>`).join('');
      const R = c.records ? c.records() : null;
      F.el.querySelector('[data-r=recs]').innerHTML = R && R.list.length ? `<h3>${esc(R.title || 'Recordes')}</h3><div class="jf-recs">` + R.list.map(r => `<div><span>${esc(r[0])}</span><b>${esc(r[1])}</b></div>`).join('') + '</div>' : '';
      focusFirst();
    } else focusFirst();
  };
  F.hide = function(){ F.active = false; F.el.hidden = true; for(const e of (F.cfg.cover || [])) if(e) e.style.visibility = ''; F.cfg.onHide && F.cfg.onHide(); };
  F.home = function(){ F.show('hub'); };
  /* diálogos do jogo (novidades, como jogar) abertos a partir do menu ficam por cima dele */
  F.raise = function(...els){ for(const e of els) if(e) e.style.zIndex = 60; };
  /* botão "‹ Voltar ao menu" dentro do menu próprio de cada modo */
  F.backButton = function(container, label){
    const b = el('button', 'jf-back jf-backbar', label || '‹ Voltar ao menu'); b.type = 'button';
    b.addEventListener('click', e => { e.preventDefault(); e.stopPropagation(); F.show('hub'); });
    container.insertBefore(b, container.firstChild); return b;
  };
  function focusables(){ const s = F.el.querySelector(`.jf-s[data-s=${F.screen}]`); return s ? [...s.querySelectorAll('button:not([disabled])')].filter(b => b.offsetParent) : []; }
  function focusFirst(){ const l = focusables(); const f = F.screen === 'trophies' ? l[0] : l.find(b => b.classList.contains('jf-tile')) || l[0]; f && f.focus({preventScroll:true}); }
  function move(d){ const l = focusables(); if(!l.length) return; let i = l.indexOf(document.activeElement); i = i < 0 ? 0 : (i + d + l.length) % l.length; l[i].focus(); }
  function back(){ if(F.screen === 'trophies') F.show('hub'); }
  function onKey(e){
    if(!F.active) return;
    if(F.cfg.blockWhen && F.cfg.blockWhen()) return;
    const k = e.code;
    e.stopImmediatePropagation();
    if(F.screen === 'title'){ if(!['ShiftLeft', 'ShiftRight', 'ControlLeft', 'AltLeft', 'MetaLeft', 'Tab'].includes(k)){ e.preventDefault(); start(); } return; }
    if(k === 'ArrowDown' || k === 'ArrowRight'){ e.preventDefault(); move(1); }
    else if(k === 'ArrowUp' || k === 'ArrowLeft'){ e.preventDefault(); move(-1); }
    else if(k === 'Escape' || k === 'Backspace'){ e.preventDefault(); back(); }
  }
  function pollPad(){
    requestAnimationFrame(pollPad);
    if(!F.active || (F.cfg.blockWhen && F.cfg.blockWhen())) { padPrev = {}; return; }
    let pads = []; try{ pads = [...(navigator.getGamepads ? navigator.getGamepads() : [])].filter(Boolean); }catch(e){}
    for(const g of pads){
      const b = i => !!(g.buttons[i] && (g.buttons[i].pressed || g.buttons[i].value > .5)), ay = g.axes[1] || 0, ax = g.axes[0] || 0;
      const now = {a:b(0), b:b(1), st:b(9), up:b(12) || ay < -.6 || b(14) || ax < -.6, dn:b(13) || ay > .6 || b(15) || ax > .6}, p = padPrev[g.index] || now;
      if(F.screen === 'title'){ if((now.a && !p.a) || (now.st && !p.st)) start(); }
      else {
        if(now.up && !p.up) move(-1); if(now.dn && !p.dn) move(1);
        if((now.a && !p.a) || (now.st && !p.st)){ const a = document.activeElement; if(a && F.el.contains(a)) a.click(); }
        if(now.b && !p.b) back();
      }
      padPrev[g.index] = now;
    }
  }
  window.JovoneFront = F;
})();
