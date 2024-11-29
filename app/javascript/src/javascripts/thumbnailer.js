import Thumbnailer from "./uploader/thumbnailer.vue.erb";
import { createApp } from "vue";

export default {
  init () {
    const app = createApp(Thumbnailer);
    app.mount("#thumbnailer");
  },
};
