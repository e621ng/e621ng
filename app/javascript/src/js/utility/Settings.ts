let _data = {}, loaded = false;
const _get = function () {
  if (loaded) return _data;
  try {
    const base64 = document.getElementById("site-settings").textContent;
    const json = atob(base64);
    _data = JSON.parse(json);
    loaded = true;
    return _data;
  } catch (e) {
    _data = {};
    loaded = true;
    console.error("Failed to load site settings:", e);
    return {};
  }
};

/*
  Settings values passed from the back-end.
  These are accessed via getters that replace themselves with the actual value on first access.
  This allows us to avoid parsing JSON until it is needed, and also gives control over the structure
  and contents of the Settings object exposed to the rest of the codebase.
*/

const Settings = {} as {
  Analytics: {
    enabled: boolean,
    client_id: string | null,
    events: {
      recommendation: boolean,
      search_trend: boolean,
    }
  },
  Posts: {
    webp_enabled: boolean,
  },
  Recommender: {
    remote: boolean,
  },
};

Object.defineProperty(Settings, "Analytics", {
  configurable: true,
  get () {
    const obj = _get()["Analytics"] || {};
    const value = {
      enabled: obj.enabled || false,
      client_id: obj.client_id || null,
      events: {
        recommendation: obj.events?.recommendation || false,
        search_trend: obj.events?.search_trend || false,
      },
    };
    Object.defineProperty(Settings, "Analytics", { value, writable: false });
    return value;
  },
});

Object.defineProperty(Settings, "Posts", {
  configurable: true,
  get () {
    const obj = _get()["Posts"] || {};
    const value = {
      webp_enabled: obj.webp_enabled || false,
    };
    Object.defineProperty(Settings, "Posts", { value, writable: false });
    return value;
  },
});

Object.defineProperty(Settings, "Recommender", {
  configurable: true,
  get () {
    const obj = _get()["Recommender"] || {};
    const value = {
      remote: obj.remote || false,
    };
    Object.defineProperty(Settings, "Recommender", { value, writable: false });
    return value;
  },
});

export default Settings;
