// post-favorites

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import BlacklistQuickEdit from "@/pages/posts/BlacklistQuickEdit";

State.onReady(() => {
  void BlacklistQuickEdit.instance;

  ModuleRegistry.register("v_post-favorites");
});
