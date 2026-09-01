// static # home

import ModuleRegistry from "@/utility/ModuleRegistry";

import "@/pages/static/home/Home";
import MascotManager from "@/pages/static/home/MascotManager";

ModuleRegistry.register("v_static_home", {
  "Mascot": MascotManager.instance,
});
