/**
 * CStorage is a utility class for managing user preferences stored in cookies.
 * 
 * Note: careful consideration is necessary when adding new properties. Storing these values in
 * cookies means that they are sent to the server with every request. These should only include
 * preferences that need to be read server-side to ensure correct page rendering - for example,
 * avoiding a large page reflow when hiding an element that would be otherwise shown by default.
 * 
 * Any non-essential preferences should be stored in LStorage instead.
 */
export default class CStorage {

  /** @returns true if the DMail notice is hidden, otherwise false */
  static get hideDMailNotice (): boolean {
    return this._getBoolCookie("hide_dmail_notice");
  }

  /** @param value true to hide the DMail notice, otherwise false */
  static set hideDMailNotice (value: boolean) {
    if (value) this._setBoolCookie("hide_dmail_notice", true);
    else this._deleteBoolCookie("hide_dmail_notice");
  }

  /** @returns "comments" if the post tab is set to comments, otherwise "tags" */
  static get postMobileTabState (): "comments" | "tags" {
    return this._getBoolCookie("post_tab") ? "comments" : "tags";
  }

  /** @param value "comments" to set the post tab to comments, otherwise "tags" */
  static set postMobileTabState (value: "comments" | "tags") {
    if (value === "comments") this._setBoolCookie("post_tab", true);
    else this._deleteBoolCookie("post_tab");
  }

  /** @returns true if the post recommender is hidden, otherwise false */
  static get postRecommenderHidden (): boolean {
    return this._getBoolCookie("post_recs");
  }

  /** @param value true to hide the post recommender, otherwise false */
  static set postRecommenderHidden (value: boolean) {
    if (value) this._setBoolCookie("post_recs", true);
    else this._deleteBoolCookie("post_recs");
  }

  /* ===== Utility Methods ===== */

  /**
   * Retrieves a boolean value from a cookie. The cookie is expected to be "1" for true and "0" for false.
   * @param name The name of the cookie to retrieve.
   * @returns True if the cookie value is "1", otherwise false.
   */
  private static _getBoolCookie (name: string): boolean {
    const cookies = document.cookie.split(";");
    for (const cookie of cookies) {
      const [key, value] = cookie.trim().split("=");
      if (key === name)
        return value === "1";
    }
    return false;
  }

  /**
   * Sets a boolean value in a cookie. The value is stored as "1" for true and "0" for false.  
   * The cookie will expire after the specified number of days.
   * @param name The name of the cookie to set.
   * @param value The boolean value to store in the cookie.
   * @param days The number of days until the cookie expires (default is 365).
   */
  private static _setBoolCookie (name: string, value: boolean, days: number = 365): void {
    const cookieValue = value ? "1" : "0";
    const expires = new Date(Date.now() + (days * 24 * 60 * 60 * 1000)).toUTCString();
    document.cookie = `${name}=${cookieValue}; expires=${expires}; path=/; SameSite=Lax;`;
  }

  /**
   * Deletes a boolean value from a cookie by setting its expiration date to a past date.
   * @param name The name of the cookie to delete.
   */
  private static _deleteBoolCookie (name: string): void {
    document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; SameSite=Lax;`;
  }
}
