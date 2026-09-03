import Page from "@/utility/Page.js";
import $ from "jquery";

const UploaderModule = {
  async init () {
    const uploaderElement = document.getElementById("uploader");
    if (!uploaderElement) return;
    window.Danbooru.Uploader = UploaderModule;

    // Import Vue as needed
    const [{ createApp }, { default: Uploader }] = await Promise.all([
      import("vue"),
      import("./uploader.vue"),
    ]);

    const app = createApp(Uploader);
    app.mount("#uploader");
  },
};

$(() => {
  if (!Page.matches("uploads", "new")) return;
  UploaderModule.init().catch(console.error);
});

export default UploaderModule;
