// users # edit

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import SettingsNav from "@/pages/users/edit/SettingsNav";

State.onReady(() => {
  void SettingsNav.instance;
});

ModuleRegistry.register("v_users_edit");
