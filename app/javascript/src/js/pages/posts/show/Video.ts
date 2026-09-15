import { VideoPlayerElement } from "@videojs/html/video";

async function importVideoJS() {
  // player must be loaded first
  await import("@videojs/html/video/player");

  await Promise.all([
    import("@videojs/html/icons/element"),
    import("@videojs/html/ui/container"),
    import("@videojs/html/ui/controls"),
    import("@videojs/html/ui/gesture"),
    import("@videojs/html/ui/play-button"),
    import("@videojs/html/ui/time"),
    import("@videojs/html/ui/volume-popover"),
    import("@videojs/html/ui/mute-button"),
    import("@videojs/html/ui/time-slider")
  ]);
}

class VideoPlayer {
  private videoElement: HTMLVideoElement;

  public constructor(private container: VideoPlayerElement) {
    this.videoElement = container.querySelector("video");
    this.videoElement.volume = parseFloat(localStorage.getItem("video_volume") || "1.0")
    this.videoElement.addEventListener("volumechange", () => {
			 localStorage.setItem('video_volume', this.videoElement.volume.toString());
    })
  }
}

(async () => {
  const videoPlayerContainer = $<VideoPlayerElement>(".video-player");
	if (!videoPlayerContainer.length) return;

  await importVideoJS();

  new VideoPlayer(videoPlayerContainer[0]);
})();
