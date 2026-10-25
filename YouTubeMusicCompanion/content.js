// Isolated content script: no cookies, private endpoints, lyrics or audio extraction.
let lastSent = 0;
let attachedVideo;
function sample(event) {
  const now = Date.now();
  const urgent = event && event.type !== "timeupdate";
  if (!urgent && now - lastSent < 950) return;
  lastSent = now;
  const bar = document.querySelector("ytmusic-player-bar");
  const video = document.querySelector("video");
  if (video && attachedVideo !== video) {
    if (attachedVideo) {
      for (const event of ["timeupdate", "seeked", "play", "pause", "ratechange", "ended", "loadedmetadata"])
        attachedVideo.removeEventListener(event, sample);
    }
    attachedVideo = video;
    for (const event of ["timeupdate", "seeked", "play", "pause", "ratechange", "ended", "loadedmetadata"])
      video.addEventListener(event, sample, { passive: true });
  }
  const title = bar?.querySelector(".title")?.textContent?.trim() || "";
  const links = [...(bar?.querySelectorAll(".byline a, .subtitle a") || [])];
  const artist = links[0]?.textContent?.trim() || bar?.querySelector(".byline")?.textContent?.split("•")[0]?.trim() || "";
  const album = links.length > 1 ? links[1].textContent.trim() : "";
  const ad = !!document.querySelector(".ad-showing, .ad-interrupting");
  const valid = !!video && !!title && !ad && Number.isFinite(video.duration) && video.duration > 0;
  const payload = {
    trackID: new URL(location.href).searchParams.get("v") || title.slice(0, 180),
    title: title.slice(0, 500), artist: artist.slice(0, 500), album: album.slice(0, 500),
    duration: valid ? video.duration : 0,
    position: valid ? Math.max(0, video.currentTime) : 0,
    playing: valid && !video.paused && !video.ended,
    rate: video?.playbackRate || 1,
    valid
  };
  chrome.runtime.sendMessage({ type: "songcrumb-playback", payload }).catch(() => {});
}
sample();
// Media timeupdate provides the playing heartbeat. This also discovers replaced media elements.
setInterval(sample, 2000);
document.addEventListener("visibilitychange", sample);
