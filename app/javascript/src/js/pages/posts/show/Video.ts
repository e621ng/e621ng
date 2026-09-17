import type { VideoPlayerElement } from "@videojs/html/video";

async function importVideoJS () {
  // player must be loaded first
  await import("@videojs/html/video/player");

  await Promise.all([
    import("@videojs/html/ui/container"),
    import("@videojs/html/ui/controls"),
    import("@videojs/html/ui/gesture"),
    import("@videojs/html/ui/play-button"),
    import("@videojs/html/ui/time"),
    import("@videojs/html/ui/volume-popover"),
    import("@videojs/html/ui/mute-button"),
    import("@videojs/html/ui/time-slider"),
    import("@videojs/html/ui/fullscreen-button"),
    // @ts-expect-error this thing doesn't have any d.ts file defined.
    import("@videojs/html/ui/popover"),
  ]);
}

class VideoPlayer {
  private videoElement: HTMLVideoElement;
  private muteButton: HTMLElement;

  public constructor (private container: VideoPlayerElement) {
    this.videoElement = container.querySelector("video");
    this.muteButton = container.querySelector(".mute-button");
    this.videoElement.addEventListener("volumechange", this.volumeChange);
    this.loadVolume();
  }

  private volumeChange = () => {
    const actualValue = this.videoElement.muted ? 0 : this.videoElement.volume;
    this.muteButton
      .querySelectorAll(".icon.show")
      .forEach((e) => e.classList.remove("show"));
    this.muteButton
      .querySelector(`.icon.${VideoPlayer.getVolumeIconFromValue(actualValue)}`)
      .classList.add("show");
    this.storeVolume();
  };

  public storeVolume () {
    // muted != volume set to 0. we store both states to allow muting and unmuting while retaining vol.
    localStorage.setItem("video_volume", this.videoElement.volume.toString());
    localStorage.setItem("video_muted", this.videoElement.muted.toString());
  }

  public loadVolume () {
    this.videoElement.volume = parseFloat(localStorage.getItem("video_volume") || "1.0");
    this.videoElement.muted = localStorage.getItem("video_muted") === "true";
    this.volumeChange();
  }

  public static getVolumeIconFromValue (value: number) {
    if (value == 0) return "muted";
    if (value <= 0.5) return "low";
    return "high";
  }
}

(async () => {
  const videoPlayerContainer = $<VideoPlayerElement>(".video-player");
  if (!videoPlayerContainer.length) return;

  await importVideoJS();

  new VideoPlayer(videoPlayerContainer[0]);
})();
