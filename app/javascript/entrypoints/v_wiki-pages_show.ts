// wiki_pages # show

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import SubscribeTag from "@/components/SubscribeTag";

import "@/pages/wiki_pages/show/DetailsAnchor";

State.onReady(() => {
  void SubscribeTag.instance;
});

ModuleRegistry.register("v_wiki-pages_show");
