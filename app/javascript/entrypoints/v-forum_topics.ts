// forum_topics

import E621Type from "../src/js/interfaces/E621";
declare const E621: E621Type;

import "../src/js/pages/forum_posts/forum_posts";
import "../src/js/pages/forum_topics/mark_as_read";

E621.Registry.register("v_forum_topics");
