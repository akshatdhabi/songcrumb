'use strict';
const words = ['A little room for music', 'Let the light fall into place', 'Every word a little closer', 'Every note a softer space', 'Keep a little room for music', 'Let it follow through your day'];
const panel = document.querySelector('#lyric-panel');
const lines = document.querySelector('#lyric-lines');
const play = document.querySelector('#play');
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
let active = 1;
let playing = !reduced.matches;
let timer;
for (const word of words) { const line = document.createElement('p'); line.textContent = word; lines.append(line); }
function render() {
  [...lines.children].forEach((line, index) => line.classList.toggle('active', index === active));
  const available = document.querySelector('.lyric-viewport').clientHeight;
  lines.style.transform = `translateY(${available / 2 - 14 - active * 28}px)`;
  play.textContent = playing ? 'Ⅱ' : '▶';
  play.setAttribute('aria-label', playing ? 'Pause demo animation' : 'Play demo animation');
}
function schedule() {
  clearInterval(timer);
  if (playing && !document.hidden) timer = setInterval(() => { active = (active + 1) % words.length; render(); }, 4000);
}
play.addEventListener('click', () => { playing = !playing; render(); schedule(); });
document.querySelector('#next').addEventListener('click', () => { active = (active + 1) % words.length; render(); schedule(); });
for (const button of document.querySelectorAll('[data-mode]')) button.addEventListener('click', () => {
  panel.classList.toggle('floating', button.dataset.mode === 'floating');
  for (const option of document.querySelectorAll('[data-mode]')) option.setAttribute('aria-pressed', String(option === button));
});
const colors = {white: '#f4f3ee', peach: '#ffc39b', mint: '#87f5c9'};
for (const button of document.querySelectorAll('[data-color]')) button.addEventListener('click', () => {
  panel.style.setProperty('--lyric', colors[button.dataset.color]);
  for (const option of document.querySelectorAll('[data-color]')) option.setAttribute('aria-pressed', String(option === button));
});
document.querySelector('#opacity').addEventListener('input', event => panel.style.setProperty('--glass', Number(event.target.value) / 100));
document.addEventListener('visibilitychange', schedule);
reduced.addEventListener('change', () => { if (reduced.matches) { playing = false; render(); schedule(); } });
new ResizeObserver(render).observe(document.querySelector('.lyric-viewport'));
render(); schedule();
