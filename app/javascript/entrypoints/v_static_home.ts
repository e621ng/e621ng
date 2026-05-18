// static # home

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/pages/static/home/Home";
import MascotManager from "@/pages/static/home/MascotManager";

E621.Registry.register("v_static_home", {
  "Mascot": MascotManager.instance,
});
