import LStorage from "@/utility/storage/Local";
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
    this.storeVolume();
  };

  public storeVolume () {
    // muted != volume set to 0. we store both states to allow muting and unmuting while retaining vol.
    LStorage.Posts.Video.Volume = this.videoElement.volume;
    LStorage.Posts.Video.Muted = this.videoElement.muted;
  }

  public loadVolume () {
    this.videoElement.volume = LStorage.Posts.Video.Volume;
    this.videoElement.muted = LStorage.Posts.Video.Muted;
    this.volumeChange();
  }
}

(async () => {
  const videoPlayerContainer = $<VideoPlayerElement>(".video-player");
  if (!videoPlayerContainer.length) return;

  await importVideoJS();

  new VideoPlayer(videoPlayerContainer[0]);
})();
