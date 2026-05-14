import Offclick, { OffclickEntry } from "@/utility/Offclick";

class Navigation {

  private $wrapper: JQuery<HTMLElement>;
  private $avatarMenu: JQuery<HTMLElement>;

  private mainMenuOffclick: OffclickEntry | null = null;
  private avatarMenuOffclick: OffclickEntry | null = null;

  private constructor () {
    this.$wrapper = $("html");
    this.$avatarMenu = $(".simple-avatar-menu");

    this.bootstrapMainMenu();
    this.bootstrapAvatarMenu();
  }

  /* ============================== */
  /* ==== Bootstrapping Events ==== */
  /* ============================== */

  /**
   * Sets up the main menu toggle button and offclick handler.
   * The offclick handler is registered on the first toggle to avoid unnecessary overhead on pages where it's not needed.
   */
  private bootstrapMainMenu () {
    $("#nav-toggle").on("click", (event) => {
      event.preventDefault();

      if (this.mainMenuOffclick === null)
        this.mainMenuOffclick = Offclick.register("#nav-toggle", ".nav-primary, .nav-secondary, .nav-tools, .nav-help", () => {
          this.$wrapper.removeClass("nav-toggled");
          if (this.avatarMenuOffclick)
            this.avatarMenuOffclick.disabled = true;
        });

      // Toggle the main menu
      this.mainMenuOffclick.disabled = !this.mainMenuOffclick.disabled;
      this.$wrapper.toggleClass("nav-toggled", !this.mainMenuOffclick.disabled);

      // Clean up the avatar menu
      if (this.avatarMenuOffclick)
        this.avatarMenuOffclick.disabled = true;
    });
  }

  /**
   * Sets up the avatar menu toggle button and offclick handler.
   * The offclick handler is registered on the first toggle to avoid unnecessary overhead on pages where it's not needed.
   */
  private bootstrapAvatarMenu () {
    if (this.$avatarMenu.length === 0) return;
    const $avatarButton = $(".simple-avatar");
    if ($avatarButton.length === 0) return;

    if (!AvatarMenuLoader.hasCachedData)
      AvatarMenuLoader.syncUserData();

    // Toggle menu on click
    $avatarButton.on("click", (event) => {
      event.preventDefault();

      // Register offclick handler on the first use
      if (this.avatarMenuOffclick === null)
        this.avatarMenuOffclick = Offclick.register(".simple-avatar", ".simple-avatar-menu", () => {
          this.$avatarMenu.addClass("hidden");
          if (this.mainMenuOffclick)
            this.mainMenuOffclick.disabled = true;
        });

      // Toggle the avatar menu
      this.avatarMenuOffclick.disabled = !this.avatarMenuOffclick.disabled;
      this.$avatarMenu.toggleClass("hidden", this.avatarMenuOffclick.disabled);

      // Clean up the main menu
      if (this.mainMenuOffclick)
        this.mainMenuOffclick.disabled = true;
    });

    // Load menu data on first click
    $avatarButton.one("click", async () => {
      const userID = $avatarButton.data("user-id");
      if (!userID) return;

      // This could cause the menu to be slightly out of sync with the data from the back-end.
      // However, it is an acceptable trade-off to prevent the UI from reflowing right as the
      // user is about to interact with the menu. Plus, this situation is quite rare.
      this.buildAvatarMenu();
      AvatarMenuLoader.syncUserData();
      this.adjustAvatarNameSize();
    });
  }

  /**
   * Builds the avatar menu based on cached user data.
   * If no cached data is available, the menu will not be modified.
   */
  private buildAvatarMenu () {
    const userStats = AvatarMenuLoader.loadCachedData();
    if (!userStats) return;

    $(".simple-avatar-menu")
      .toggleClass("has-uploads", userStats.has_uploads)
      .toggleClass("has-favorites", userStats.has_favorites)
      .toggleClass("has-sets", userStats.has_sets)
      .toggleClass("has-comments", userStats.has_comments)
      .toggleClass("has-forums", userStats.has_forums);
  }

  /**
   * Adjusts the font size of the avatar menu name to fit within its container.
   * This is necessary because users can have very long names that would overflow the menu.
   */
  private adjustAvatarNameSize () {
    const element = document.querySelector(".simple-avatar-menu .savm-profile-name") as HTMLElement;
    if (!element || element.scrollWidth <= element.clientWidth) return;

    const fontSize = Math.max(0.5, element.clientWidth / element.scrollWidth);
    element.style.fontSize = `${fontSize}rem`;
  }


  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: Navigation;
  public static get instance (): Navigation {
    if (!Navigation._instance)
      Navigation._instance = new Navigation();
    return Navigation._instance;
  }
}

class AvatarMenuLoader {

  private static cacheKey = "e6.avatar.menu";
  private static syncInProgress: Promise<AvatarMenuData> | null = null;

  /**
   * Checks if cached avatar menu data is available.
   * This does not guarantee that the data is valid, only that it exists in localStorage.
   * @returns {boolean} True if cached data is available, false otherwise.
   */
  public static get hasCachedData (): boolean {
    return localStorage.getItem(this.cacheKey) !== null;
  }

  /**
   * Loads cached avatar menu data from localStorage.
   * If the data is not available or fails to parse, null is returned.
   * @returns {AvatarMenuData | null} The cached avatar menu data, or null if not available.
   */
  public static loadCachedData (): AvatarMenuData | null {
    const data = localStorage.getItem(this.cacheKey);
    if (!data) return null;

    try {
      return JSON.parse(data) as AvatarMenuData;
    } catch (error) {
      console.error("Avatar menu: failed to parse cached data", error);
      return null;
    }
  }

  /**
   * Fetches avatar menu data from the server and caches it in localStorage.
   * If a sync is already in progress, the existing promise is returned to avoid duplicate requests.
   * @returns {Promise<AvatarMenuData>} A promise that resolves to the avatar menu data.
   */
  public static async syncUserData (): Promise<AvatarMenuData> {
    if (this.syncInProgress)
      return this.syncInProgress;

    this.syncInProgress = fetch("/users/avatar_menu.json", {
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
    }).then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    }).then((data: AvatarMenuData) => {
      localStorage.setItem(this.cacheKey, JSON.stringify({
        has_uploads: data.has_uploads,
        has_favorites: data.has_favorites,
        has_sets: data.has_sets,
        has_comments: data.has_comments,
        has_forums: data.has_forums,
      }));

      return data;
    }).catch(error => {
      console.error("Avatar menu: failed to load content", error);
      return Promise.reject(error);
    }).finally(() => {
      this.syncInProgress = null;
    });

    return this.syncInProgress;
  }
}

type AvatarMenuData = {
  has_uploads: boolean;
  has_favorites: boolean;
  has_sets: boolean;
  has_comments: boolean;
  has_forums: boolean;
};

$(() => {
  if (!$("nav.navigation").length) return;
  void Navigation.instance;
});
