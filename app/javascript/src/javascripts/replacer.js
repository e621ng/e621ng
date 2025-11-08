import Page from "./utility/page.js";
import $ from "jquery";

const ReplacerModule = {
  async init () {
    const replacerElement = document.getElementById("replacement-uploader");
    if (!replacerElement) return;
    window.Danbooru.Replacer = ReplacerModule;

    // Import Vue as needed
    const [{ createApp }, { default: Replacer }] = await Promise.all([
      import("vue"),
      import("./replacement_uploader.vue"),
    ]);

    const dataset = replacerElement.dataset;
    window.uploaderSettings = {
      maxFileSize: parseInt(dataset.maxFileSize || "0"),
      maxFileSizeMap: JSON.parse(dataset.maxFileSizeMap || "{}"),
    };

    const app = createApp(Replacer);
    app.mount("#replacement-uploader");
  },
};

$(() => {
  if (!Page.matches("post-replacements", "new")) return;
  ReplacerModule.init().catch(console.error);
});

export default ReplacerModule;
