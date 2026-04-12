import Flash from "@/components/Flash";
import Logger from "@/components/Logger";
import ModuleRegistry from "@/components/ModuleRegistry";
import Blacklist from "@/core/blacklists";
import Settings from "@/utility/settings";
import LStorage from "@/utility/storage";

export default interface E621Type {
  Registry: ModuleRegistry;
  LStorage: typeof LStorage;
  Settings: typeof Settings;
  Blacklist: typeof Blacklist;
  Logger: typeof Logger;
  Flash: typeof Flash;
}
