import State from "@/utility/StateUtils";

export default class MascotManager {

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
      this._current = this.availableIDs[Math.floor(Math.random() * this.availableIDs.length)];
    this.showMascot();

    document.getElementById("mascot-swap")?.addEventListener("click", this.handleChangeMascot.bind(this));
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

    try {
      const binString = atob((mascotsElement.textContent || "").trim());
      const bytes = Uint8Array.from(binString, (m) => m.charCodeAt(0));
      const decodedData = new TextDecoder().decode(bytes);
      this.mascots = JSON.parse(decodedData);
    } catch (error) {
      console.error("Mascot data could not be decoded or parsed", error);
      return false;
    }

    if (Object.keys(this.mascots).length === 0) {
      console.warn("No mascot data found");
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
    if (isNaN(this._current) || (this._current != 0 && !this.mascots[this._current + ""])) {
      console.warn(`Invalid mascot ID: ${value}`);
      this._current = 0;
    }

    if (!this._current)
      localStorage.removeItem("mascot");
    else
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

    const body = document.body;
    body.style.setProperty("--bg-image", `url("${mascot.background_url}")`);
    body.style.setProperty("--bg-color", mascot.background_color);
    body.style.setProperty("--fg-color", mascot.foreground_color);

    if (mascot.is_layered)
      body.setAttribute("layered", "true");
    else body.removeAttribute("layered");

    const mascotArtist = document.getElementById("mascot-artist");
    if (!mascotArtist) return;

    if (mascot.artist_name && mascot.artist_url) {
      const safeUrl = /^https?:\/\//i.test(mascot.artist_url) ? mascot.artist_url : "#";
      mascotArtist.textContent = "Mascot by ";

      const artistLink = document.createElement("a");
      artistLink.textContent = mascot.artist_name;
      artistLink.href = safeUrl;
      mascotArtist.append(artistLink);
    } else mascotArtist.textContent = "";
  }

  private handleChangeMascot (event: MouseEvent) {
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
  id: number,
  background_url: string;
  background_color: string;
  foreground_color: string;
  is_layered: boolean;
  artist_name: string;
  artist_url: string;
}

State.onReady(() => {
  void MascotManager.instance;
});
