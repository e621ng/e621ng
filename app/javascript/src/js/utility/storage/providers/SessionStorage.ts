import LocalStorageProvider from "./LocalStorage";

export default class SessionStorageProvider extends LocalStorageProvider {
  name = "SessionStorage";
  get source () { return sessionStorage; }
}
