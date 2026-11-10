window.jvUp = async (n, branch) => {
  const S = ms => new Promise(r => setTimeout(r, ms));
  const base = 'https://raw.githubusercontent.com/Jhovict/Jovone/' + branch + '/';
  const m = await (await fetch(base + 'm' + n + '.json')).json();
  const v = new File([await (await fetch(base + 'v' + n + '.mp4')).blob()], 'v' + n + '.mp4', { type: 'video/mp4' });
  const t = new File([await (await fetch(base + 't' + n + '.jpg')).blob()], 't' + n + '.jpg', { type: 'image/jpeg' });
  const put = (inp, f) => { const dt = new DataTransfer(); dt.items.add(f); inp.files = dt.files; inp.dispatchEvent(new Event('change', { bubbles: true })); };
  const set = (el, txt) => { el.focus(); document.execCommand('selectAll'); document.execCommand('insertText', false, txt); el.dispatchEvent(new Event('input', { bubbles: true })); };
  for (let k = 0; k < 20 && !document.querySelector('input[type=file][name=Filedata]'); k++) await S(500);
  put(document.querySelector('input[type=file][name=Filedata]'), v);
  for (let k = 0; k < 30 && document.querySelectorAll('#textbox').length < 2; k++) await S(500);
  await S(1500);
  const tb = [...document.querySelectorAll('#textbox')];
  set(tb[0], m.titulo); set(tb[1], m.descricao);
  put(document.querySelector('input#file-loader'), t);
  document.querySelector('tp-yt-paper-radio-button[name=VIDEO_MADE_FOR_KIDS_NOT_MFK]').click();
  document.querySelector('#toggle-button').click(); await S(1500);
  const ti = document.querySelector('#tags-container input#text-input');
  ti.focus(); ti.value = m.tags.join(',') + ','; ti.dispatchEvent(new Event('input', { bubbles: true }));
  ti.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true })); ti.blur();
  await S(500);
  const chips = document.querySelectorAll('ytcp-chip').length;
  document.querySelector('tp-yt-paper-radio-button[name=VIDEO_HAS_ALTERED_CONTENT_NO]').click();
  await S(800);
  for (let k = 0; k < 3; k++) { document.querySelector('#next-button').click(); await S(1500); }
  return { titulo: m.titulo, chips };
};
window.jvAg = async (dia, mes, hora) => {
  const S = ms => new Promise(r => setTimeout(r, ms));
  if (!document.querySelector('ytcp-scrollable-calendar')) { document.querySelector('#second-container-expand-button')?.click(); await S(800); document.querySelector('#datepicker-trigger').click(); await S(1000); }
  const mm = [...document.querySelectorAll('ytcp-scrollable-calendar .calendar-month')].find(e => e.querySelector('.calendar-month-label')?.innerText.startsWith(mes));
  const d = [...mm.querySelectorAll('.calendar-day')].find(e => e.innerText.trim() === String(dia));
  d.click(); await S(1200);
  const tIn = [...document.querySelectorAll('input')].find(i => /^\d{1,2}:\d{2}$/.test(i.value));
  tIn.click(); tIn.focus(); await S(1000);
  const it = [...document.querySelectorAll('tp-yt-paper-item')].find(e => e.innerText.trim() === hora);
  it.scrollIntoView(); it.click(); await S(900);
  const vals = [...document.querySelectorAll('input')].map(i => i.value).filter(v => /:\d\d$|\d{4}$/.test(v));
  return [document.querySelector('#datepicker-trigger')?.innerText.trim(), vals];
};
window.jvFim = async () => {
  const S = ms => new Promise(r => setTimeout(r, ms));
  const b = document.querySelector('#done-button'); const t = b.innerText; b.click(); await S(3000);
  [...document.querySelectorAll('ytcp-button, button')].filter(x => x.offsetParent && x.innerText.trim() === 'Ok').forEach(x => x.click());
  await S(3000); return t;
};
window.jvTodo = async (n, dia, mes, hora) => { const r = await jvUp(n, 'tmp-videos10'); const a = await jvAg(dia, mes, hora); const f = await jvFim(); return [r, a, f]; };
