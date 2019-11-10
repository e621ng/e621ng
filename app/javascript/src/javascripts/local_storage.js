let LS = {
  put(name, value) {
    localStorage[name] = value;
  },
  get(name) {
    return localStorage[name];
  }
};

export default LS;
