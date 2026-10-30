// takedowns

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import TakedownEditor from "@/pages/takedowns/TakedownEditor";

State.onReady(() => {
  void TakedownEditor.instance;

  ModuleRegistry.register("v_takedowns", { TakedownEditor: TakedownEditor.instance });
});
