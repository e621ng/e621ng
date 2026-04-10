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

const Settings = {
  get Analytics () {
    const obj = _get().analytics || {};
    delete Settings.Analytics;
    Settings.Analytics = {
      enabled: obj.enabled || false,
      client_id: obj.client_id || null,
      events: { // Synchronize with Analytics.Event enum
        recommendation: obj.events?.recommendation || false,
        search_trend: obj.events?.search_trend || false,
      },
    };
    return Settings.Analytics;
  },
};

export default Settings;
