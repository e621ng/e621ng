// forum_topics

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import "@/pages/forum_posts/ForumPostVote";
import PollVote from "@/pages/forum_topics/PollVote";

State.onReady(() => {
  void PollVote.instance;
});

ModuleRegistry.register("v_forum-topics_show");
