import Logger from "@/utility/Logger";
import Settings from "@/utility/Settings";
import { OpenPanel } from "@openpanel/web";

class Analytics {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: Analytics | null = null;
  public static get instance () {
    if (!this._instance) {
      this._instance = new Analytics(Settings.Analytics.client_id);
    }
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private op: OpenPanel | null = null;
  private Logger: Logger;

  private constructor (clientID: string) {
    if (Analytics._instance)
      throw new Error("Analytics is a singleton class. Use Analytics.instance to access the instance.");

    this.Logger = new Logger("Analytics");

    if (Settings.Analytics.enabled) {
      if (!clientID) throw new Error("clientID is required");

      this.op = new OpenPanel({
        apiUrl: "https://op.dragonfru.it/api",
        clientId: clientID,
        trackScreenViews: true,
        trackOutgoingLinks: true,
        trackAttributes: true,
        sessionReplay: {
          enabled: false,
        },
      });

      const output = ["OpenPanel initialized"];
      for (const [key, value] of Object.entries(Settings.Analytics.events))
        if (value) output.push(` ⤷ ${key} : enabled`);
      this.Logger.log(output.join("\n"));
    }
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /**
   * Record an analytics event with the given name and attributes.  
   * The event will only be recorded if analytics are enabled.
   * @param event The name of the event to track.
   * @param attributes A key-value map of attributes to associate with the event.
   */
  public track (event: keyof EventConfig, attributes: Record<string, any> = {}) {
    if (!this.enabled || !this.op) return;
    if (!Object.keys(this.Events).includes(event)) {
      console.warn(`Analytics event "${event}" is not defined in Settings.Analytics.events. Event will not be tracked.`);
      return;
    }
    if (!this.Events[event]) return;

    this.op.track(event, attributes);
    this.Logger.log(`Tracked event: ${event}`, attributes);
  }

  /**
   * @returns True if analytics are enabled, false otherwise.
   */
  public get enabled (): boolean {
    return !!Settings.Analytics.enabled;
  }

  /**
   * @returns The list of events that are enabled for tracking.
   */
  public get Events (): EventConfig {
    if (!Settings.Analytics.enabled) return { recommendation: false, search_trend: false };
    return Settings.Analytics.events;
  }
}

export default Analytics.instance;

interface EventConfig {
  recommendation: boolean;
  search_trend: boolean;
};
