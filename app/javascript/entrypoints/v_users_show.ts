// users # show

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import MobileTabs from "@/components/MobileTabs";
import "@/pages/users/show/ProfileCard";
import "@/pages/users/show/ProfileReadMore";
import "@/pages/users/show/ProfileSection";
import "@/pages/users/show/staff_notes";

State.onReady(() => {
  MobileTabs.initAll();
});

ModuleRegistry.register("v_users_show");
