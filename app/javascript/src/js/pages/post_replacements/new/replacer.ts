// No jquery import: $ is an injected global (see jquery-shims.d.ts) — an
// explicit import would resolve @types/jquery's broken ESM declarations.
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
