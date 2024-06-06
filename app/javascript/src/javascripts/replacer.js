import Replacer from "./replacement_uploader.vue";
import { createApp } from "vue";

export default {
  init(canApprove) {
    const app = createApp(Replacer, { canApprove });
    app.mount("#replacement-uploader");
  }
}
