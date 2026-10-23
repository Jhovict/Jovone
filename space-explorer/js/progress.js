// Progresso salvo no navegador: estatísticas, troféus e recordes (usados pelo menu Jovone Games e pelo launcher).
SE.Progress = (function () {
  const KEY = 'spaceExplorer.stats';
  const BEST_KEY = 'spaceExplorer.best.saturn';
  const U = SE.U;

  function load() {
    let s = {};
    try { s = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { s = {}; }
    return Object.assign({ plays: 0, runs: 0, crystalsBest: 0, stomps: 0, falls: 0, allCrystals: false, allCores: false, allMites: false, three: false, noFall: false, perfect: false }, s);
  }
  function save(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* sem armazenamento */ } }
  function best() { try { const v = parseFloat(localStorage.getItem(BEST_KEY)); return isFinite(v) && v > 0 ? v : 0; } catch (e) { return 0; } }

  function trophies(S, b) {
    S = S || load(); b = b === undefined ? best() : b;
    return [
      { icon: '🚀', name: 'Primeira missão', desc: 'chegue à Estação Anel-9', got: S.runs >= 1 },
      { icon: '💎', name: 'Garimpeiro', desc: 'colete todos os cristais numa partida', got: S.allCrystals, prog: 'recorde ' + S.crystalsBest },
      { icon: '🟡', name: 'Trio de núcleos', desc: 'pegue os 3 núcleos e conclua', got: S.allCores },
      { icon: '⭐', name: 'Três estrelas', desc: 'conclua com as 3 estrelas', got: S.three },
      { icon: '🪶', name: 'Pés firmes', desc: 'conclua sem nenhuma queda', got: S.noFall },
      { icon: '👾', name: 'Pisoteio', desc: 'derrote os 5 ácaros numa partida', got: S.allMites },
      { icon: '🦶', name: 'Caça-ácaros', desc: 'derrote 25 ácaros no total', got: S.stomps >= 25, prog: Math.min(S.stomps, 25) + '/25' },
      { icon: '⏱', name: 'Veloz', desc: 'conclua em menos de 1:30', got: b > 0 && b < 90, prog: b ? 'melhor ' + U.fmtTime(b) : '' },
      { icon: '🔁', name: 'Veterano', desc: 'conclua a fase 5 vezes', got: S.runs >= 5, prog: Math.min(S.runs, 5) + '/5' },
      { icon: '💯', name: 'Missão perfeita', desc: 'todos os cristais e núcleos, sem quedas, numa só partida', got: S.perfect },
    ];
  }

  function records() {
    const S = load(), b = best();
    return {
      title: 'Recordes', list: [
        ['Melhor tempo', b ? U.fmtTime(b) : '—'],
        ['Missões concluídas', String(S.runs)],
        ['Mais cristais numa partida', S.crystalsBest + ' / 53'],
        ['Ácaros derrotados', String(S.stomps)],
        ['Partidas iniciadas', String(S.plays)],
        ['Quedas no total', String(S.falls)],
      ]
    };
  }

  function started() { const S = load(); S.plays++; save(S); }

  // Chamado ao concluir a fase; devolve os nomes dos troféus conquistados agora
  function complete(W, newBest) {
    const S = load();
    const before = trophies(S, best()).filter(function (t) { return t.got; }).map(function (t) { return t.name; });
    const st = W.stats;
    const allC = st.crystals >= W.totalCrystals, allK = st.cores >= W.totalCores;
    S.runs++;
    S.crystalsBest = Math.max(S.crystalsBest, st.crystals);
    S.stomps += st.stomps || 0;
    S.falls += st.falls;
    if (allC) S.allCrystals = true;
    if (allK) S.allCores = true;
    if ((st.stomps || 0) >= W.mites.length) S.allMites = true;
    if (allK && st.crystals >= Math.ceil(W.totalCrystals * 0.8)) S.three = true;
    if (st.falls === 0) S.noFall = true;
    if (allC && allK && st.falls === 0) S.perfect = true;
    save(S);
    return trophies(S, newBest).filter(function (t) { return t.got && before.indexOf(t.name) < 0; }).map(function (t) { return t.name; });
  }

  // Ácaros e quedas de partidas abandonadas também contam no total
  function abandon(W) {
    if (!W || W.titleMode || W.complete) return;
    const S = load();
    S.stomps += W.stats.stomps || 0;
    S.falls += W.stats.falls;
    S.crystalsBest = Math.max(S.crystalsBest, W.stats.crystals);
    save(S);
  }

  return { load: load, best: best, trophies: trophies, records: records, started: started, complete: complete, abandon: abandon };
})();
