import $ from "jquery";
import { createApp } from "vue";
import Uploader from "./uploader.vue";

const UploaderModule = {
  init () {
    const uploaderElement = document.getElementById("uploader");
    if (!uploaderElement) return;
    window.Danbooru.Uploader = UploaderModule;

    const app = createApp(Uploader);
    app.mount("#uploader");
  },
};

$(() => { UploaderModule.init(); });

export default UploaderModule;
