class MascotManager {

  private mascots: Record<string, MascotData> = {};
  private availableIDs: number[];

  private constructor () {
    if (!this.loadMascotData())
      return;
    // Backwards compatibility
    window["mascots"] = this.mascots;

    this.availableIDs = Object.keys(this.mascots)
      .map(id => parseInt(id))
      .filter(id => !isNaN(id));

    if (!this.mascots[this.current + ""])
      this.current = this.availableIDs[Math.floor(Math.random() * this.availableIDs.length)];
    this.showMascot();

    $("#mascot-swap").on("click", this.handleChangeMascot.bind(this));
  }

  /**
   * Loads mascot data from the DOM, decodes it, and parses it into the mascots property.
   * @returns {boolean} True if the data was successfully loaded and parsed, false otherwise.
   */
  private loadMascotData (): boolean {
    const mascotsElement = document.getElementById("home-mascots");
    if (!mascotsElement) {
      console.error("Mascot data element not found");
      return false;
    }

    if (mascotsElement.getAttribute("data-encoding") !== "base64") {
      console.error("Mascot data encoding not found");
      return false;
    }

    const decodedData = atob((mascotsElement.textContent || "").trim());
    try {
      this.mascots = JSON.parse(decodedData);
    } catch (error) {
      console.error("Mascot data could not be parsed", error);
      return false;
    }

    return true;
  }


  /* ============================== */
  /* ======== Getter Magic ======== */
  /* ============================== */

  private _current: number;
  private get current (): number {
    if (typeof this._current !== "number") {
      this._current = parseInt(localStorage.getItem("mascot") || "0") || 0;
    }
    return this._current;
  }

  private set current (value: string | number) {
    this._current = typeof value === "string" ? parseInt(value) : value;
    localStorage.setItem("mascot", this._current.toString());
  }


  /* ============================== */
  /* ======= Utility Methods ====== */
  /* ============================== */

  /**
   * Updates the page's style and mascot artist information based on the provided mascot.
   * @param mascotID The ID of the mascot to display. Defaults to the current mascot if not provided.
   */
  private showMascot (mascotID: number = this.current): void {
    const mascot = this.mascots[mascotID + ""];
    if (!mascot) return;

    const $body = $("body").css({
      "--bg-image": `url("${mascot.background_url}")`,
      "--bg-color": mascot.background_color,
      "--fg-color": mascot.foreground_color,
    });

    if (mascot.is_layered)
      $body.attr("layered", "true");
    else $body.removeAttr("layered");

    $("#mascot-artist")
      .text("Mascot by ")
      .append($("<a>").text(mascot.artist_name).attr("href", mascot.artist_url));
  }

  private handleChangeMascot (event: JQuery.ClickEvent) {
    event.preventDefault();

    const currentMascotIndex = this.availableIDs.indexOf(this.current);
    this.current = this.availableIDs[(currentMascotIndex + 1) % this.availableIDs.length];

    this.showMascot();
  }


  /* ============================== */
  /* ====== Singleton Pattern ===== */
  /* ============================== */

  private static _instance: MascotManager;
  static get instance () {
    if (!MascotManager._instance)
      MascotManager._instance = new MascotManager();
    return MascotManager._instance;
  }
}

interface MascotData {
  background_url: string;
  background_color: string;
  foreground_color: string;
  is_layered: boolean;
  artist_name: string;
  artist_url: string;
}

$(function () {
  void MascotManager.instance;
});
