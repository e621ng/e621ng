import Post from "@/pages/posts/posts";
import Page from "@/utility/Page";
import LStorage from "@/utility/storage";
import Utility from "@/utility/utility";

const EDGE_ZONE = 20; // px — ignore swipes starting this close to screen edge (browser back/forward gesture)
const MIN_DISTANCE = 150; // px — minimum total path length
const MIN_VELOCITY = 0.2; // px/ms — minimum average velocity
const MAX_REST_MS = 300; // ms — max time since last move point before gesture is discarded
const DIRECTION_RATIO = 1.6; // horizontal displacement must exceed vertical by this factor

interface TouchPoint {
  x: number;
  y: number;
  time: number;
}

class SwipeGestureHandler {
  private moves: TouchPoint[] = [];
  private canceled = false;

  constructor () {
    document.body.addEventListener("touchstart", this.onStart, { passive: true });
    document.body.addEventListener("touchmove", this.onMove, { passive: true });
    document.body.addEventListener("touchend", this.onEnd, { passive: true });
    window.addEventListener("pageshow", this.onPageShow);
    $("#image-container").css({ overflow: "visible" });
  }

  private onPageShow = (e: PageTransitionEvent): void => {
    if (e.persisted)
      $("body").css({ transition: "", opacity: "", transform: "" });
  };

  private onStart = (e: TouchEvent): void => {
    const t = e.touches[0];
    this.moves = [{ x: t.clientX, y: t.clientY, time: Date.now() }];
    this.canceled = false;
  };

  private onMove = (e: TouchEvent): void => {
    if (this.canceled) return;
    if (e.touches.length > 1) {
      this.canceled = true;
      return;
    }
    const t = e.touches[0];
    this.moves.push({ x: t.clientX, y: t.clientY, time: Date.now() });
  };

  private onEnd = (): void => {
    if (this.canceled || this.moves.length < 3) return;

    const ae = document.activeElement;
    if (ae && ["INPUT", "TEXTAREA", "SELECT"].includes(ae.tagName)) return;

    const last = this.moves[this.moves.length - 1];
    if (Date.now() - last.time > MAX_REST_MS) return;

    const first = this.moves[0];
    const dx = last.x - first.x;
    const dy = last.y - first.y;

    if (Math.abs(dx) <= Math.abs(dy) * DIRECTION_RATIO) return;
    if (dx > 0 && first.x < EDGE_ZONE) return;
    if (dx < 0 && first.x > window.innerWidth - EDGE_ZONE) return;

    let totalDist = 0;
    for (let i = 1; i < this.moves.length; i++) {
      const a = this.moves[i - 1], b = this.moves[i];
      totalDist += Math.hypot(b.x - a.x, b.y - a.y);
    }
    if (totalDist < MIN_DISTANCE) return;

    const duration = last.time - first.time;
    if (duration <= 0 || totalDist / duration < MIN_VELOCITY) return;

    if (dx > 0 && Post.has_prev_target()) {
      $("body").css({ transition: "opacity 100ms ease, transform 100ms ease", opacity: "0", transform: "translateX(150%)" });
      Utility.delay(0).then(() => Post.nav_prev()); // Apply CSS changes before navigating
    } else if (dx < 0 && Post.has_next_target()) {
      $("body").css({ transition: "opacity 100ms ease, transform 100ms ease", opacity: "0", transform: "translateX(-150%)" });
      Utility.delay(0).then(() => Post.nav_next()); // Apply CSS changes before navigating
    }
  };
}

function getNextHref (): string | undefined {
  return $(".search-seq-nav a[rel~=next]").attr("href")
    || $(".paginator a[rel~=next]").attr("href")
    || $(".pool-nav li.pool-selected-true a[rel~=next], .set-nav li.set-selected-true a[rel~=next]").attr("href");
}

$(() => {
  if (!LStorage.Theme.Gestures) return;
  if (!Page.matches("posts", "show")) return;
  if (!("ontouchstart" in window) && !(navigator.maxTouchPoints > 0)) return;
  new SwipeGestureHandler();

  const nextHref = getNextHref();
  if (nextHref)
    $("<link>").attr({ rel: "prefetch", href: nextHref }).appendTo("head");
});
