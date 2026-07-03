export default class State {

  /**
   * Executes the provided callback when the DOM is fully loaded.
   * If the DOM is already loaded, the callback is executed immediately.
   * @param callback The function to execute when the DOM is ready.
   */
  public static onReady (callback: () => void): void {
    if (document.readyState === "loading")
      document.addEventListener("DOMContentLoaded", callback, { once: true });
    else callback();
  }
}
