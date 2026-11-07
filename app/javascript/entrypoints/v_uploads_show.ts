// uploads # show

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import "@/pages/uploads/show";

State.onReady(() => {
  ModuleRegistry.register("v_uploads_show");
});
