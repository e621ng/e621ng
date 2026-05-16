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
    return CookieJar.getBool("hide_dmail_notice");
  }

  static set hideDMailNotice (value: boolean) {
    if (value) CookieJar.setBool("hide_dmail_notice", true);
    else CookieJar.delete("hide_dmail_notice");
  }


  /** @returns "comments" if the post tab is set to comments, otherwise "tags" */
  static get postMobileTabState (): "comments" | "tags" {
    return CookieJar.getBool("post_tab") ? "comments" : "tags";
  }

  static set postMobileTabState (value: "comments" | "tags") {
    if (value === "comments") CookieJar.setBool("post_tab", true);
    else CookieJar.delete("post_tab");
  }


  /** @returns true if the post recommender is hidden, otherwise false */
  static get postRecommenderHidden (): boolean {
    return CookieJar.getBool("post_recs");
  }

  static set postRecommenderHidden (value: boolean) {
    if (value) CookieJar.setBool("post_recs", true);
    else CookieJar.delete("post_recs");
  }


  /** @returns The ID of the currently selected mascot, or 0 if the default mascot is being used */
  static get mascotID (): number {
    const id = CookieJar.get("mascot");
    return id ? (parseInt(id) || 0) : 0;
  }

  static set mascotID (value: number) {
    if (value > 0) CookieJar.set("mascot", value.toString(), "/");
    else CookieJar.delete("mascot");
  }
}

/**
 * Helper class for managing cookies.
 * Should not be used directly - add helper methods to CStorage instead.
 */
class CookieJar {
  /**
   * Retrieves the value of a cookie by its name. If the cookie does not exist, it returns null.
   * @param name The name of the cookie to retrieve.
   * @returns The value of the cookie, or null if the cookie does not exist.
   */
  public static get (name: string): string | null {
    const cookies = document.cookie.split(";");
    for (const cookie of cookies) {
      const [key, value] = cookie.trim().split("=");
      if (key === name)
        return value;
    }
    return null;
  }

  /**
   * Sets a cookie with the specified name, value, and expiration in days.
   * The cookie is set with the path "/" and SameSite=Lax for security.
   * @param name The name of the cookie to set.
   * @param value The value to store in the cookie.
   * @param path The path for which the cookie is valid (default is "/").
   * @param days The number of days until the cookie expires (default is 365).
   */
  public static set (name: string, value: string, path: string = "/", days: number = 365): void {
    const expires = new Date(Date.now() + (days * 24 * 60 * 60 * 1000)).toUTCString();
    document.cookie = `${name}=${value}; expires=${expires}; path=${path}; SameSite=Lax;`;
  }

  /**
   * Deletes a cookie by setting its expiration date to a past date, effectively removing it from the browser.
   * @param name The name of the cookie to delete.
   * @param path The path of the cookie to delete (default is "/").
   */
  public static delete (name: string, path: string = "/"): void {
    document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=${path}; SameSite=Lax;`;
  }


  /**
   * Retrieves a boolean value from a cookie. The cookie is expected to be "1" for true and "0" for false.
   * @param name The name of the cookie to retrieve.
   * @returns True if the cookie value is "1", otherwise false.
   */
  public static getBool (name: string): boolean {
    return this.get(name) === "1";
  }

  /**
   * Sets a boolean value in a cookie. The value is stored as "1" for true and "0" for false.  
   * The cookie will expire after the specified number of days.
   * @param name The name of the cookie to set.
   * @param value The boolean value to store in the cookie.
   * @param path The path for which the cookie is valid (default is "/").
   * @param days The number of days until the cookie expires (default is 365).
   */
  public static setBool (name: string, value: boolean, path: string = "/", days: number = 365): void {
    this.set(name, value ? "1" : "0", path, days);
  }
}
