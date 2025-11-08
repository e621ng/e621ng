import Page from "./utility/page.js";
import $ from "jquery";

const UploaderModule = {
  async init () {
    const uploaderElement = document.getElementById("uploader");
    if (!uploaderElement) return;
    window.Danbooru.Uploader = UploaderModule;

    // Import Vue as needed
    const [{ createApp }, { default: Uploader }] = await Promise.all([
      import("vue"),
      import("./uploader/uploader.vue"),
    ]);

    const dataset = uploaderElement.dataset;
    window.uploaderSettings = {
      compactMode: dataset.compactMode === "true",
      safeSite: dataset.safeSite === "true",
      uploadTags: JSON.parse(dataset.uploadTags || "[]"),
      recentTags: JSON.parse(dataset.recentTags || "[]"),
      allowLockedTags: dataset.allowLockedTags === "true",
      allowRatingLock: dataset.allowRatingLock === "true",
      allowUploadAsPending: dataset.allowUploadAsPending === "true",
      maxFileSize: parseInt(dataset.maxFileSize || "0"),
      maxFileSizeMap: JSON.parse(dataset.maxFileSizeMap || "{}"),
      verifiedArtistTags: JSON.parse(dataset.verifiedArtistTags || "[]"),
    };

    const app = createApp(Uploader);
    app.mount("#uploader");
  },
};

$(() => {
  if (!Page.matches("uploads", "new")) return;
  UploaderModule.init().catch(console.error);
});

export default UploaderModule;
