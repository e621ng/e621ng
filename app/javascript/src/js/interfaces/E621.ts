import Blacklist from "@/core/blacklists";
import Flash from "@/utility/Flash";
import Logger from "@/utility/Logger";
import ModuleRegistry from "@/utility/ModuleRegistry";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import LStorage from "@/utility/storage";

export default interface E621Type {
  Registry: ModuleRegistry;
  Performance: PerformanceTracker;
  LStorage: typeof LStorage;
  Settings: typeof Settings;
  Blacklist: typeof Blacklist;
  Logger: typeof Logger;
  Flash: typeof Flash;
}
