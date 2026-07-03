import ImageCropWidget from "@/components/image_crop_widget.vue";
import { App, createApp } from "vue";

$(() => {
  const widgetEl = document.getElementById("avatar-crop-widget");
  if (!widgetEl) return;

  const imageUrl = widgetEl.dataset.imageUrl;
  const nw = parseInt(widgetEl.dataset.naturalWidth ?? "", 10);
  const nh = parseInt(widgetEl.dataset.naturalHeight ?? "", 10);
  if (!imageUrl || !nw || !nh) return;

  const app: App = createApp(ImageCropWidget, {
    imageUrl,
    naturalWidth: nw,
    naturalHeight: nh,
    aspectRatio: 1,
    minSize: 256,
    onCropChange (coords: { x: number; y: number; w: number; h: number }) {
      (document.getElementById("avatar_crop_x") as HTMLInputElement).value = String(coords.x);
      (document.getElementById("avatar_crop_y") as HTMLInputElement).value = String(coords.y);
      (document.getElementById("avatar_crop_w") as HTMLInputElement).value = String(coords.w);
    },
  });
  app.mount(widgetEl);
});
