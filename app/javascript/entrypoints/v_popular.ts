// popular

import State from "@/utility/StateUtils";

import BlacklistQuickEdit from "@/pages/posts/BlacklistQuickEdit";

State.onReady(() => {
  void BlacklistQuickEdit.instance;
});
