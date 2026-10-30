import HTTP from "@/utility/HTTP";
import ToastManager from "@/utility/Toast";

/** The "Active" toggle buttons in the mascots#index table */
export default class MascotActiveToggles {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: MascotActiveToggles | null = null;
  public static get instance (): MascotActiveToggles {
    if (!MascotActiveToggles._instance)
      MascotActiveToggles._instance = new MascotActiveToggles();
    return MascotActiveToggles._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (MascotActiveToggles._instance)
      throw new Error("MascotActiveToggles is a singleton class. Use MascotActiveToggles.instance to access the instance.");

    document.querySelector("#c-mascots")?.addEventListener("click", (event) => {
      const button = (event.target as Element).closest<HTMLButtonElement>("button.mascot-active-toggle");
      if (button) void this.toggle(button);
    });
  }


  /* ============================== */
  /* =========== Actions ========== */
  /* ============================== */

  /** Sends the inverse of the button's current state; the button only changes once the server confirms */
  public async toggle (button: HTMLButtonElement): Promise<void> {
    if (button.disabled) return;
    const active = button.getAttribute("aria-pressed") !== "true";

    button.disabled = true;
    button.setAttribute("aria-busy", "true");
    try {
      const response = await HTTP.request(`/mascots/${button.dataset.mascotId}.json`, {
        method: "PATCH",
        body: new URLSearchParams({ "mascot[active]": String(active) }),
      });
      if (response.ok) button.setAttribute("aria-pressed", String(active));
      else ToastManager.alert(await HTTP.errorMessage(response));
    } catch {
      ToastManager.alert("Failed to update mascot");
    } finally {
      button.disabled = false;
      button.removeAttribute("aria-busy");
    }
  }

}
