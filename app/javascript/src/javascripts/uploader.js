import Uploader from "./uploader/uploader.vue.erb";
import { createApp } from "vue";

export default {
  init () {
    const app = createApp(Uploader);
    app.mount("#uploader");
  },
};
