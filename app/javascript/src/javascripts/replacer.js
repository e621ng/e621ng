import Replacer from "./replacement_uploader.vue";
import { createApp } from "vue";

export default {
  init () {
    const app = createApp(Replacer);
    app.mount("#replacement-uploader");
  },
};
