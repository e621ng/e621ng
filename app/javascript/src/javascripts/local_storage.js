let LS = {
  put(name, value) {
    localStorage[name] = value;
  },
  putObject(name, value) {
    this.put(name, JSON.stringify(value));
  },
  get(name) {
    return localStorage[name];
  },
  getObject(name) {
    const value = this.get(name);
    try {
      return JSON.parse(value);
    } catch (error) {
      return null;
    }
  }
};

export default LS;
