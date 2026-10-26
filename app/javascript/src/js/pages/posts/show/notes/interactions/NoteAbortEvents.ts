import NoteUtilities from "@/pages/posts/show/notes/NoteUtilities";

/**
 * Fires `note:abort` on the container whenever an in-progress drag can no
 * longer be trusted: the window loses focus or resizes, the page is hidden,
 * or the user presses Escape.
 */
export default class NoteAbortEvents {

  public constructor () {
    const abort = () => { NoteUtilities.container.trigger("note:abort"); };

    // Window losing focus causes the script to think that the mouse button is still held down.
    // Resize events will affect coordinate calculations.
    $(window).on("blur.e6.note resize.e6.note", abort);

    $(document).on("keydown.e6.note", (event) => {
      if (event.key !== "Escape") return;
      abort();
    });

    $(document).on("visibilitychange.e6.note", () => {
      if (!document.hidden) return;
      abort();
    });
  }
}
