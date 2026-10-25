const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..', 'YouTubeMusicCompanion');
(async () => {
  let listener; const calls = []; let storage = { token: 'a'.repeat(64) };
  const chrome = {
    runtime: { getURL: p => `chrome-extension://fixture/${p}`, onMessage: { addListener(fn) { listener = fn; } } },
    storage: { local: {
      async setAccessLevel(value) { assert.equal(value.accessLevel, "TRUSTED_CONTEXTS"); },
      async get() { return storage; }, async set(value) { Object.assign(storage, value); }
    } }
  };
  vm.runInNewContext(fs.readFileSync(path.join(root, 'background.js'), 'utf8'), {
    chrome, URL, Date, AbortSignal,
    fetch: async (url, options) => { calls.push({url, options}); return { ok: true }; }
  });
  const payload = {trackID:'fixture',title:'Song',artist:'Artist',album:'',duration:100,position:4,playing:true,rate:1,valid:true};
  const message = {type:'songcrumb-playback',payload};
  listener(message, {tab:{id:1}, url:'https://evil.example/'});
  await new Promise(setImmediate); assert.equal(calls.length, 0);
  listener(message, {tab:{id:1}, url:'https://music.youtube.com/watch?v=fixture'});
  await new Promise(setImmediate); assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://127.0.0.1:48537/v1/playback');
  assert.equal(calls[0].options.headers.Authorization, `Bearer ${storage.token}`);
  assert.equal(calls[0].options.credentials, 'omit');
  assert.deepEqual(JSON.parse(calls[0].options.body), payload);
  listener({type:'songcrumb-playback',payload:{...payload,playing:false}}, {tab:{id:2},url:'https://music.youtube.com/'});
  await new Promise(setImmediate); assert.equal(calls.length, 1); // paused second tab cannot take over
  let sent; let ad = false;
  const video = {duration:100,currentTime:12,playbackRate:1,paused:false,ended:false,addEventListener(){}};
  const bar = {querySelector: s => s === '.title' ? {textContent:'Song'} : null,
    querySelectorAll: () => [{textContent:'Artist'}, {textContent:'Album'}]};
  const document = {querySelector: s => s === 'video' ? video : s === 'ytmusic-player-bar' ? bar : ad ? {} : null,
    addEventListener(){}};
  let tick;
  vm.runInNewContext(fs.readFileSync(path.join(root,'content.js'),'utf8'), {
    document, URL, location:{href:'https://music.youtube.com/watch?v=fixture'}, Date,
    setInterval(fn) { tick = fn; }, chrome:{runtime:{sendMessage: async value => {sent=value;}}}
  });
  assert.equal(sent.payload.title,'Song'); assert.equal(sent.payload.artist,'Artist');
  assert.equal(sent.payload.position,12); assert.equal(sent.payload.valid,true);
  console.log('Companion: sender isolation, fixed destination, pairing, multi-tab ownership and metadata fixture checks passed.');
})();
