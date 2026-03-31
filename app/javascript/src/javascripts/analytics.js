import { OpenPanel } from "@openpanel/web";
import Page from "./utility/page";

export default class Analytics {

  constructor (clientID) {
    if (!clientID) throw new Error("clientID is required");

    this._op = new OpenPanel({
      apiUrl: "https://op.dragonfru.it/api",
      clientId: clientID,
      trackScreenViews: true,
      trackOutgoingLinks: true,
      trackAttributes: true,
    });

    // Disabled for performance reasons, for now.
    // this.bootstrapSearchData();
  }

  bootstrapSearchData () {
    if (!Page.matches("posts", "index")) return;
    const query = $("#tags").val() || "";
    let resultsCount = $(".approximate-count").data("count") || 0;
    this._op.track("search", {
      query: query,
      queryLength: query.split(" ").length,
      resultsCount: resultsCount,
      hasResults: resultsCount > 0,
    });
  }

  static _instance = null;
  static _init () {
    this._instance = new Analytics(window.op_client_id);
  }

  static trigger (event, attributes = {}) {
    if (!this._instance) return;
    this._instance.track(event, attributes);
  }

}

$(() => {
  if (!window.op_client_id) return;
  Analytics._init();
});
