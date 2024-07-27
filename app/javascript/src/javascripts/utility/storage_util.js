const StorageUtils = {};

/**
 * Creates a getter and a setter based on specified params
 * @param {Object} params Storage configuration
 */
StorageUtils.bootstrap = function (object, accessor, key, fallback) {
  const type = typeof fallback;

  Object.defineProperty(object, accessor, {
    get () { return StorageUtils.getProxy(key, type, fallback); },
    set (value) { StorageUtils.setProxy(key, value, type, fallback); },
  });
};

StorageUtils.bootstrapMany = function (object) {
  for (const [accessor, params] of Object.entries(object))
    StorageUtils.bootstrap(object, accessor, params[0], params[1]);
};

StorageUtils.getProxy = function (key, type, fallback) {
  let val = localStorage.getItem(key);
  if (val === null) return fallback;
  switch (type) {
    case "number":
      return parseInt(val, 10);
    case "boolean":
      return val === "true";
    case "object":
      return JSON.parse(val);
  }
  return val;
};

StorageUtils.setProxy = function (key, value, type, fallback) {
  if (value == fallback) {
    localStorage.removeItem(key);
    return;
  }

  if (type == "object") value = JSON.stringify(value);
  localStorage.setItem(key, value);
};

export default StorageUtils;
