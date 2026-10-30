// popular

import State from "@/utility/StateUtils";

import BlacklistQuickEdit from "@/components/BlacklistQuickEdit";

State.onReady(() => {
  void BlacklistQuickEdit.instance;
});
