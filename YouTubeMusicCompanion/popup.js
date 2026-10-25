const input = document.getElementById("token");
const status = document.getElementById("status");
chrome.storage.local.get(["token", "status"]).then(data => {
  input.value = data.token || "";
  status.textContent = data.status || "Open music.youtube.com to connect.";
});
document.getElementById("save").addEventListener("click", async () => {
  const token = input.value.trim();
  if (!/^[a-f0-9]{64}$/i.test(token)) { status.textContent = "Use the full 64-character token from Songcrumb Settings."; return; }
  await chrome.storage.local.set({ token, status: "Paired locally. Play a song at music.youtube.com." });
  await chrome.runtime.sendMessage({type:"songcrumb-reconnect"});
  status.textContent = "Paired locally. Play a song at music.youtube.com.";
});
document.getElementById("disconnect").addEventListener("click", async () => {
  await chrome.storage.local.remove("token");
  input.value = ""; status.textContent = "Disconnected. No playback data will be sent.";
});

document.getElementById("retry").addEventListener("click", async () => {
  await chrome.runtime.sendMessage({type:"songcrumb-reconnect"});
  status.textContent = "Retrying on the next playback update…";
});
