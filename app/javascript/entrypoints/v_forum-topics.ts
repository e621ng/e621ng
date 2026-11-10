// forum_topics

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import "@/pages/forum_posts/forum_posts";
import "@/pages/forum_topics/mark_as_read";
import PollForm from "@/pages/forum_topics/PollForm";

State.onReady(() => {
  void PollForm.instance;
});

ModuleRegistry.register("v_forum-topics");
