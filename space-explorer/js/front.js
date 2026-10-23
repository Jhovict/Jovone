// Abertura padrão Jovone Games (../shared/menu.js): título, menu principal, troféus, novidades e opções.
(function () {
  const VERSION = '1.1';
  const SEEN_KEY = 'spaceExplorer.seen';
  const G = SE.Game, PR = SE.Progress, U = SE.U;
  const news = document.getElementById('news');
  const help = document.getElementById('help');

  function openDlg(d) { d.hidden = false; d.firstElementChild.scrollTop = 0; const b = d.querySelector('[data-close]'); b && b.focus({ preventScroll: true }); }
  function closeDlg(d) {
    d.hidden = true;
    if (d === news) { try { localStorage.setItem(SEEN_KEY, VERSION); } catch (e) {} }
    if (window.JovoneFront && JovoneFront.active) JovoneFront.show(JovoneFront.screen); else JovoneFront.show('hub');
  }
  document.getElementById('news-ver').textContent = 'Versão ' + VERSION;
  [news, help].forEach(function (d) {
    d.querySelector('[data-close]').addEventListener('click', function () { closeDlg(d); });
  });
  const open = function () { return !news.hidden ? news : !help.hidden ? help : null; };
  addEventListener('keydown', function (e) {
    const d = open(); if (!d) return;
    if (e.code === 'Escape' || e.code === 'Enter' || e.code === 'Space' || e.code === 'Backspace') { e.preventDefault(); e.stopImmediatePropagation(); closeDlg(d); }
  }, true);
  // controle: A ou B fecha os painéis
  let prevPad = false;
  (function pad() {
    requestAnimationFrame(pad);
    const d = open();
    let gp = null; try { gp = [].slice.call(navigator.getGamepads ? navigator.getGamepads() : []).filter(Boolean)[0]; } catch (e) {}
    const now = !!(gp && ((gp.buttons[0] && gp.buttons[0].pressed) || (gp.buttons[1] && gp.buttons[1].pressed)));
    if (d && now && !prevPad) closeDlg(d);
    prevPad = now;
  })();

  if (!window.JovoneFront) return;

  const stats = function () {
    const S = PR.load(), b = PR.best(), out = [];
    if (b) out.push('⏱ ' + U.fmtTime(b) + ' melhor tempo');
    if (S.runs) out.push('🚀 ' + S.runs + (S.runs === 1 ? ' missão' : ' missões'));
    return out;
  };
  const again = function () { JovoneFront.show('hub'); };
  const FR = JovoneFront.init({
    id: 'space-explorer', root: document.getElementById('stage'),
    title: 'SPACE', title2: 'EXPLORER', tagline: 'Fase 1 · Saturno · Anel de Gelo', accent: '#7ff6ff', version: 'versão ' + VERSION,
    blockWhen: function () { return !!open(); },
    onStart: function () { try { if (localStorage.getItem(SEEN_KEY) !== VERSION) setTimeout(function () { openDlg(news); }, 300); } catch (e) {} },
    stats: stats,
    tiles: function () {
      return [
        { icon: '🪐', name: 'Jogar', desc: 'Fase 1 · Saturno — cristais, 3 núcleos e a Estação Anel-9', big: true, go: G.play },
        { icon: '📖', name: 'Como jogar', desc: 'controles, perigos e estrelas', go: function () { JovoneFront.show('hub'); openDlg(help); } },
        { icon: '🏆', name: 'Troféus', desc: 'galeria e recordes', trophies: true },
        { name: G.muted ? '🔇 Som: desligado' : '🔊 Som: ligado', small: true, go: function () { G.toggleMute(); again(); } },
        { name: '⛶ Tela cheia', small: true, go: function () { G.toggleFullscreen(); again(); } },
        { name: '✦ Novidades', small: true, go: function () { JovoneFront.show('hub'); openDlg(news); } },
      ];
    },
    trophies: function () { return PR.trophies(); },
    records: function () { return PR.records(); },
  });
  FR.raise(news, help);
})();
