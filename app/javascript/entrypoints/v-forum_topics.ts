// forum_topics

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/pages/forum_posts/forum_posts";
import "@/pages/forum_topics/mark_as_read";

E621.Registry.register("v-forum_topics");
