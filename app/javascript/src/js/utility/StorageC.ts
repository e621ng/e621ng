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

  /** @param value true to hide the search trends, otherwise false */
  static get hideSearchTrends (): boolean {
    return this._getBitValue(BitCookieIndex.HideSearchTrends);
  }

  static set hideSearchTrends (value: boolean) {
    this._setBitValue(BitCookieIndex.HideSearchTrends, value === true);
  }

  /** @returns "comments" if the post tab is set to comments, otherwise "tags" */
  static get postMobileTabState (): "comments" | "tags" {
    return this._getBitValue(BitCookieIndex.PostMobileTabState) ? "comments" : "tags";
  }

  /** @param value "comments" to set the post tab to comments, otherwise "tags" */
  static set postMobileTabState (value: "comments" | "tags") {
    this._setBitValue(BitCookieIndex.PostMobileTabState, value === "comments");
  }

  /** @returns true if the post recommender is hidden, otherwise false */
  static get hidePostRecommendations (): boolean {
    return this._getBitValue(BitCookieIndex.HidePostRecommendations);
  }

  /** @param value true to hide the post recommender, otherwise false */
  static set hidePostRecommendations (value: boolean) {
    this._setBitValue(BitCookieIndex.HidePostRecommendations, value === true);
  }

  /** @param value true to hide the wiki excerpt, otherwise false */
  static get hideWikiExcerpt (): boolean {
    return this._getBitValue(BitCookieIndex.HideWikiExcerpt);
  }

  static set hideWikiExcerpt (value: boolean) {
    this._setBitValue(BitCookieIndex.HideWikiExcerpt, value === true);
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

  /* ===== Bitflag Cookie Methods ===== */

  // e6_prefs is a base2 cookie where each bit represents a different boolean preference.
  // Up to 31 preferences can be stored in a single cookie - excluding the sign bit.
  private static _bitCookieName = "e6_prefs";

  private static _getRawBitCookie (): number {
    const cookies = document.cookie.split(";");
    for (const cookie of cookies) {
      const [key, value] = cookie.trim().split("=");
      if (key === this._bitCookieName)
        return parseInt(value, 2) || 0;
    }
    return 0;
  }

  private static _getBitValue (index: BitCookieIndex): boolean {
    const rawValue = this._getRawBitCookie();
    return (rawValue & (1 << index)) !== 0;
  }

  private static _setBitValue (index: BitCookieIndex, value: boolean): void {
    let rawValue = this._getRawBitCookie();
    if (value) {
      rawValue |= (1 << index); // Set the bit at the specified index
    } else {
      rawValue &= ~(1 << index); // Clear the bit at the specified index
    }
    const expires = new Date(Date.now() + (365 * 24 * 60 * 60 * 1000)).toUTCString();
    document.cookie = `${this._bitCookieName}=${rawValue.toString(2)}; expires=${expires}; path=/; SameSite=Lax;`;
  }

}

enum BitCookieIndex {
  HideSearchTrends = 1,
  PostMobileTabState = 2,
  HidePostRecommendations = 3,
  HideWikiExcerpt = 4,
}
