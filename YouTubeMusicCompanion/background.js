let owner;
let sending = false;
let retryAt = 0;
let failures = 0;
let lastStatus = "";
let lastStoredAt = 0;
const storageReady = chrome.storage.local.setAccessLevel({accessLevel: "TRUSTED_CONTEXTS"});
async function saveStatus(status, now) {
  if (status !== lastStatus || now - lastStoredAt >= 15000) {
    await chrome.storage.local.set({status, lastSeen: now});
    lastStatus = status; lastStoredAt = now;
  }
}
chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.type === "songcrumb-reconnect" && sender.url === chrome.runtime.getURL("popup.html")) {
    retryAt = 0; failures = 0;
    return;
  }
  if (message?.type !== "songcrumb-playback" || !sender.tab || !sender.url) return;
  let url;
  try { url = new URL(sender.url); } catch { return; }
  if (url.origin !== "https://music.youtube.com") return;
  const p = message.payload;
  if (!p || typeof p.title !== "string" || typeof p.artist !== "string" ||
      typeof p.album !== "string" || typeof p.trackID !== "string" ||
      typeof p.valid !== "boolean" || typeof p.playing !== "boolean" ||
      !Number.isFinite(p.duration) || !Number.isFinite(p.position) || !Number.isFinite(p.rate)) return;
  if (p.title.length > 500 || p.artist.length > 500 || p.album.length > 500 || p.trackID.length > 200) return;
  const now = Date.now();
  if (owner && owner.tab !== sender.tab.id && now - owner.seen < 5000 && (owner.playing || !p.playing)) return;
  owner = { tab: sender.tab.id, playing: p.playing, seen: now };
  if (sending || now < retryAt) return;
  sending = true;
  (async () => {
    try {
      await storageReady;
      const { token } = await chrome.storage.local.get("token");
      if (!/^[a-f0-9]{64}$/i.test(token || "")) {
        await saveStatus("Paste the pairing token from Songcrumb Settings first.", now);
        return;
      }
      // Fixed destination; page messages can never choose a URL or read responses.
      const response = await fetch("http://127.0.0.1:48537/v1/playback", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` },
        body: JSON.stringify(Object.fromEntries(["trackID", "title", "artist", "album", "duration", "position", "playing", "rate", "valid"].map(key => [key, p[key]]))), signal: AbortSignal.timeout(2500),
        credentials: "omit", cache: "no-store", redirect: "error"
      });
      const status = response.ok ? (p.valid ? "Connected to Songcrumb on this Mac." : "Connected · waiting for a song / advertisement ending.") :
        (response.status === 403 ? "Pairing token rejected. Copy it again from Songcrumb." : `Songcrumb returned ${response.status}.`);
      failures = 0; retryAt = 0;
      await saveStatus(status, now);
    } catch {
      failures = Math.min(failures + 1, 4);
      retryAt = Date.now() + Math.min(30000, 2000 * 2 ** failures);
      await saveStatus("Cannot reach Songcrumb. Open the app and enable YouTube Music, then click Retry connection here. Retrying automatically with backoff.", now);
    } finally { sending = false; }
  })();
});
