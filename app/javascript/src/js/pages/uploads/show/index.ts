import { createApp } from "vue";
import UploadStatus, { type UploadJson } from "./upload_status.vue";

function parseInitial (element: HTMLElement): UploadJson | null {
  try {
    return JSON.parse(element.dataset.initial ?? "null");
  } catch {
    return null;
  }
}

const UploadStatusModule = {
  init () {
    const element = document.getElementById("upload-status");
    if (!element) return;

    const initial = parseInitial(element);
    if (!initial) return; // Keep the server-rendered fallback

    const app = createApp(UploadStatus, {
      uploadId: Number(element.dataset.uploadId),
      fileExt: element.dataset.fileExt ?? "",
      retryUrl: element.dataset.retryUrl ?? "/uploads/new",
      initial,
    });
    app.mount(element);
  },
};

$(() => { UploadStatusModule.init(); });

export default UploadStatusModule;
