// uploads # new

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import BlacklistQuickEdit from "@/pages/posts/BlacklistQuickEdit";
import "@/pages/uploads/new";

State.onReady(() => {
  void BlacklistQuickEdit.instance;

  ModuleRegistry.register("v_uploads_new");
});
