import Navigation from "@/pages/posts/show/Navigation";
import LStorage from "@/utility/storage/Local";
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

/** Swipe left / right on posts#show to go to the next / previous post. Opt-in, touch devices only. */
export default class SwipeGestureHandler {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: SwipeGestureHandler | null = null;
  public static get instance (): SwipeGestureHandler {
    if (!SwipeGestureHandler._instance)
      SwipeGestureHandler._instance = new SwipeGestureHandler();
    return SwipeGestureHandler._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private moves: TouchPoint[] = [];
  private canceled = false;

  private constructor () {
    if (SwipeGestureHandler._instance)
      throw new Error("SwipeGestureHandler is a singleton class. Use SwipeGestureHandler.instance to access the instance.");

    if (!LStorage.Theme.Gestures) return;
    if (!("ontouchstart" in window) && !(navigator.maxTouchPoints > 0)) return;

    document.body.addEventListener("touchstart", this.onStart, { passive: true });
    document.body.addEventListener("touchmove", this.onMove, { passive: true });
    document.body.addEventListener("touchend", this.onEnd, { passive: true });
    window.addEventListener("pageshow", this.onPageShow);
    $("#image-container").css({ overflow: "visible" });

    const nextHref = Navigation.nextHref();
    if (nextHref)
      $("<link>").attr({ rel: "prefetch", href: nextHref }).appendTo("head");
  }

  private onPageShow = (e: PageTransitionEvent): void => {
    if (e.persisted)
      $("body").css({ transition: "", opacity: "", transform: "" });
  };

  private onStart = (e: TouchEvent): void => {
    const t = e.touches[0];
    this.moves = [{ x: t.clientX, y: t.clientY, time: Date.now() }];
    // Drawing a wide note in editing mode must not navigate away
    this.canceled = document.getElementById("note-container")?.getAttribute("editing") === "true";
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

    if (dx > 0 && Navigation.hasPrev()) {
      $("body").css({ transition: "opacity 100ms ease, transform 100ms ease", opacity: "0", transform: "translateX(150%)" });
      Utility.delay(0).then(() => Navigation.prev()); // Apply CSS changes before navigating
    } else if (dx < 0 && Navigation.hasNext()) {
      $("body").css({ transition: "opacity 100ms ease, transform 100ms ease", opacity: "0", transform: "translateX(-150%)" });
      Utility.delay(0).then(() => Navigation.next()); // Apply CSS changes before navigating
    }
  };
}
