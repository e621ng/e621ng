// mascots

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import MascotActiveToggles from "@/pages/mascots/MascotActiveToggles";

State.onReady(() => {
  void MascotActiveToggles.instance;

  ModuleRegistry.register("v_mascots", { MascotActiveToggles: MascotActiveToggles.instance });
});
