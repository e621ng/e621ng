import { OpenPanel } from "@openpanel/web";
import Page from "@/utility/page";
import Settings from "@/utility/settings";

export default class Analytics {

  constructor (clientID) {
    if (Analytics._instance) throw new Error("Analytics has already been initialized");
    if (!clientID) throw new Error("clientID is required");

    this._op = new OpenPanel({
      apiUrl: "https://op.dragonfru.it/api",
      clientId: clientID,
      trackScreenViews: true,
      trackOutgoingLinks: true,
      trackAttributes: true,
    });

    this.enabledEvents = Settings.Analytics.events || {};

    // Event listeners should be set up in their own modules.
    // Only bootstrap them here if the module does not exist.
    this.bootstrapSearchTrendClicks();
  }

  track (event, attributes = {}) {
    if (!this.enabledEvents[event]) return;
    this._op.track(event, attributes);
  }

  bootstrapSearchTrendClicks () {
    if (!Page.matches("static", "home")) return;
    if (!Settings.Analytics.events.search_trend) return;

    $(".rising-list").one("click", "a", (event) => {
      // Only track the first click to prevent multiple events from being fired if the user clicks
      // multiple times. The links navigate away from the page regardless, so this is acceptable.
      const data = event.currentTarget.dataset;
      if (!data.tag || !data.category) return;
      this.track(Analytics.Event.SearchTrend, {
        tag: data.tag,
        category: data.category,
      });
    });
  }

  static _instance = null;
  static _init () {
    this._instance = new Analytics(Settings.Analytics.client_id);
  }

  /**
   * Record an analytics event with the given name and attributes.  
   * The event will only be recorded if analytics are enabled.
   * @param {string} event - The name of the event to track.
   * @param {Object} attributes - A key-value map of attributes to associate with the event.
   * @returns {void}
   */
  static track (event, attributes = {}) {
    if (!this._instance) return;
    this._instance.track(event, attributes);
  }

  /**
   * @returns {boolean} Whether analytics tracking is enabled or not.
   */
  static get enabled () {
    return !!Settings.Analytics.enabled;
  }

  /**
   * Enum of supported analytics events. Only events listed here will be tracked.  
   * Should be kept in sync with Settings.Analytics.events in the back-end.
   * @readonly
   * @enum {string}
   */
  static Event = {
    Recommendation: "recommendation",
    SearchTrend: "search_trend",
  };
}

$(() => {
  if (!Settings.Analytics.enabled) return;
  Analytics._init();
});
