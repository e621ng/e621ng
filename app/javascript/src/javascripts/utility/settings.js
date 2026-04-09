let _data = {}, loaded = false;
const _get = function () {
  if (loaded) return _data;
  _data = JSON.parse(document.getElementById("site-settings").textContent);
  loaded = true;
  return _data;
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
