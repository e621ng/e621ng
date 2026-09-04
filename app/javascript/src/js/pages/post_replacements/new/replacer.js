import $ from "jquery";
import { createApp } from "vue";
import Replacer from "./replacement_uploader.vue";

const ReplacerModule = {
  init () {
    const replacerElement = document.getElementById("replacement-uploader");
    if (!replacerElement) return;

    const app = createApp(Replacer);
    app.mount("#replacement-uploader");
  },
};

$(() => { ReplacerModule.init(); });

export default ReplacerModule;
