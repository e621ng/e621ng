<template>
  <div class="upload-preview-container" :class="classes && previewClass">
    <div class="box-section background-red" v-show="overDims">
      One of the image dimensions is above the maximum allowed of 15,000px and will fail to upload.
    </div>
    <div v-if="!failed">
      <div class="upload-preview-dims">{{ previewDimensions }}</div>
      <div class="upload-preview-wrapper">
        <video
          v-if="data.isVideo"
          class="upload-preview-image"
          controls
          :src="previewURL"
          ref="video"
          v-on:loadeddata="imageLoaded($event)"
          v-on:error="previewFailed()"
        ></video>
        <img
          v-else
          class="upload-preview-image"
          :src="previewURL"
          referrerpolicy="no-referrer"
          ref="image"
          v-on:load="imageLoaded($event)"
          v-on:error="previewFailed()"
        />
        <canvas
          class="upload-preview-cropper"
          ref="canvas"
        ></canvas>
      </div>
      <div class="upload-preview-thumb-dims">{{ thumbnailDimensions }}</div>
    </div>
    <div v-else class="preview-fail">
      <p>The preview for this file failed to load. Please, double check that the URL you provided is correct.</p>
      Note that some sites intentionally prevent images they host from being displayed on other sites. The file can still be uploaded despite that.
    </div>
  </div>
</template>

<script>
const thumbNone = "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==";
const handlePositions = [
  [[15, -5], [-5, -5], [-5, 15]],
  [[-15, -5], [5, -5], [5, 15]],
  [[15, 5], [-5, 5], [-5, -15]],
  [[-15, 5], [5, 5], [5, -15]],
];

export default {
  props: {
    classes: String,
    data: {
      validator: function(obj) {
        return typeof obj.isVideo === "boolean" && typeof obj.url === "string";
      }
    },
  },
  data() {
    return {
      hasData: false,
      failed: false,

      heigth: 0,
      width: 0,
      overDims: false,

      minWidth: 256,

      /** Selector position information */
      selector: {
        left: 0,
        top: 0,
        side: 0,
      },

      dragging: null,
      canvasRatio: 1,

      /** Current mouse position */
      mouse: {
        x: 0,
        y: 0,
      },

      /** Mouse position prior to movement */
      mouseOld: {
        x: 0,
        y: 0,
      },
      
    }
  },
  computed: {
    previewURL() { return this.hasData ? this.data.url : thumbNone; },
    previewClass() { return this.hasData ? "" : "disabled"; },

    previewDimensions() {
      if (this.width > 1 && this.height > 1)
        return this.width + "×" + this.height;
      return "";
    },
    thumbnail() {
      return {
        left: Math.floor(this.selector.left / this.canvasRatio),
        top: Math.floor(this.selector.top / this.canvasRatio),
        side: Math.floor(this.selector.side / this.canvasRatio),
      };
    },
    thumbnailDimensions() {
      if (!this.isSelectorValid) return;
      return this.thumbnail.left + " / "
           + this.thumbnail.top + " / "
           + this.thumbnail.side;
    },
    isSelectorValid() {
      return this.selector.left >= 0 && this.selector.top >= 0 && this.selector.side >= 1;
    },
  },
  mounted() {
    // console.log(0, "mounted")
    this.canvas = this.$refs.canvas;

    let resizeTimeout = 0;
    window.addEventListener("resize", () => {
      if(this.failed || resizeTimeout) return;
      resizeTimeout = window.setTimeout(() => {
        // TODO If image load failed
        this.resetCanvas();
        resizeTimeout = 0;
      }, 30);
    });

    this.canvas.addEventListener("mousedown", this.mouseDown, false);
    this.canvas.addEventListener("mouseup", this.mouseUp, false);
    this.canvas.addEventListener("mouseout", this.mouseUp, false);
    this.canvas.addEventListener("blur", this.mouseUp, false);

    let mouseMoveTimeout = 0;
    this.canvas.addEventListener("mousemove", (event) => {
      if(mouseMoveTimeout) return;
      mouseMoveTimeout = window.setTimeout(() => {
        this.mouseMove(event);
        mouseMoveTimeout = 0;
      }, 30);
    }, false);

    this.canvas.addEventListener("touchstart", this.mouseDown);
    this.canvas.addEventListener("touchend", this.mouseUp);

    this.canvas.addEventListener("touchmove", (event) => {
      if (mouseMoveTimeout) return;
      mouseMoveTimeout = window.setTimeout(() => {
        this.mouseMove(event);
        mouseMoveTimeout = 0;
      }, 30);
    });
  },
  watch: {

    // Step 1: Receiving data
    // The uploader / thumbnailer form sends
    // either the URL or the local file info.
    data: function() {
      // Format:
      // {
      //   url: string,
      //   isVideo: boolean,
      // }
      // console.log(1, "received data", this.data);

      // Reset the preview state
      this.failed = false;
      this.hasData = this.data.url !== "";

      this.overDims = false;
      this.width = 0;
      this.height = 0;
      this.thumbnailDimensionsChanged();

      // Reset the cropper
      var context = this.canvas.getContext("2d");
      context.clearRect(0, 0, this.canvas.width, this.canvas.height);

      this.canvas.height = this.canvas.width = 0;
      this.selector.left = this.selector.top = this.selector.size = 0;
      // console.log(1.1, "reset params");
    }
  },
  methods: {

    // Step 2: Attempting to load the image preview
    // This may fail because the file does not exist,
    // or because the remote server prevents hotlinking.
    imageLoaded(event) {

      // Stop if the placeholder image is loaded
      // Workaround for videos – the placeholder image
      // still loads alongside the video sometimes.
      const target = event.target;
      if (!this.hasData || target.src === thumbNone) return;
      // console.log(2, "image loaded");

      // Recalculate the image dimensions
      this.height = target.naturalHeight || target.videoHeight;
      this.width = target.naturalWidth || target.videoWidth;
      this.overDims = (this.height > 15000 || this.width > 15000);
      if (this.overDims) return;
      
      // console.log(2.1, "image valid");
      this.resetCanvas();
      this.thumbnailDimensionsChanged();
    },
    previewFailed() {
      // console.log(2, "image failed to load");

      this.failed = true;
      // No need to draw canvas
    },
    thumbnailDimensionsChanged() {
      // Pass the thumbnail dimensions to the outer form
      this.$emit("thumbnailDimensionsChanged", this.thumbnail);
    },


    // Step 3: Draw the cropper canvas
    resetCanvas() {
      // console.log(3, "redrawing canvas");
      const subject = this.$refs.image || this.$refs.video;

      // let oldThumbnail = this.thumbnail;
      this.canvasRatio = subject.offsetHeight / this.height;
      this.canvas.width = subject.offsetWidth;
      this.canvas.height = subject.offsetHeight;

      // This is a really dumb way of importing existing
      // thumbnail params into the thumbnailer UI
      let params = [5, 5, Math.min(subject.offsetWidth, subject.offsetHeight) - 10];
      if (this.data.thumbnail) {
        const split = this.data.thumbnail.split("/");
        if (split.length === 3) {
          for (let i = 0; i < 3; i++)
            split[i] = parseInt(split[i]) * this.canvasRatio;
          if (!Number.isNaN(split[0]) && !Number.isNaN(split[1]) && !Number.isNaN(split[2]))
            params = split;
        }
      }

      this.selector.left = params[0];
      this.selector.top = params[1];
      this.selector.side = params[2];

      this.drawRectInCanvas();
    },
    clearCanvas() {
      this.canvas.height = this.canvas.width = 0;
      var ctx = this.canvas.getContext("2d");
      ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    },
    drawRectInCanvas() {
      var ctx = this.canvas.getContext("2d");
      ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

      ctx.beginPath();
      ctx.lineWidth = "3";
      ctx.fillStyle = "rgba(199, 87, 231, 0.2)";
      ctx.strokeStyle = "#c757e7";
      
      ctx.rect(this.selector.left, this.selector.top, this.selector.side, this.selector.side);
      ctx.fill();
      ctx.stroke();

      drawHandle(this.canvas, this.selector.left, this.selector.top, 0, this.dragging == 1);
      drawHandle(this.canvas, this.selector.left + this.selector.side, this.selector.top, 1, this.dragging == 2);
      drawHandle(this.canvas, this.selector.left, this.selector.top + this.selector.side, 2, this.dragging == 3);
      drawHandle(this.canvas, this.selector.left + this.selector.side, this.selector.top + this.selector.side, 3, this.dragging == 4);

      ctx.beginPath();
      ctx.font = "16px monospace";
      ctx.fillStyle = "#000000";
      ctx.fillText("█████████", this.selector.left + 16, this.selector.top + 16)

      ctx.fillStyle = "#ffd666";
      ctx.fillText("thumbnail", this.selector.left + 16, this.selector.top + 16);

      function drawHandle(canvas, x, y, position, highlight = false) {
        var ctx = canvas.getContext("2d");
        ctx.fillStyle = highlight ? "#fe6a64" : "#c757e7";
        ctx.beginPath();

        let coords = handlePositions[position];
        ctx.moveTo(x + coords[0][0], y + coords[0][1]);
        ctx.lineTo(x + coords[1][0], y + coords[1][1]);
        ctx.lineTo(x + coords[2][0], y + coords[2][1]);

        ctx.fill();
      }
    },

    // Mouse event listeners
    updateMousePosition(event) {
      var clx, cly
      if (event.type == "touchstart" || event.type == "touchmove") {
        clx = event.touches[0].clientX;
        cly = event.touches[0].clientY;
      } else {
        clx = event.clientX;
        cly = event.clientY;
      }
      var boundingRect = this.canvas.getBoundingClientRect();
      this.mouse = {
        x: clx - boundingRect.left,
        y: cly - boundingRect.top
      };
    },

    mouseDown(event) {
      if(this.dragging !== null) return;
      this.updateMousePosition(event);

      if (isInBox(this.mouse.x, this.mouse.y, this.selector)) {
        this.dragging = 0;
        this.mouseOld = this.mouse;
        // Falls through, in case of clicking on the circle inside the box
      }

      //   | 1  2
      // --|------
      // 0 | 1  2
      // 2 | 3  4
      let vertical, horizontal;

      if (isCloseEnough(this.mouse.y, this.selector.top)) vertical = 0;
      else if (isCloseEnough(this.mouse.y, this.selector.top + this.selector.side)) vertical = 2;
      else return;

      if (isCloseEnough(this.mouse.x, this.selector.left)) horizontal = 1;
      else if (isCloseEnough(this.mouse.x, this.selector.left + this.selector.side)) horizontal = 2;
      else return;

      this.dragging = vertical + horizontal;
      this.mouseOld = this.mouse;

      this.drawRectInCanvas();

      function isInBox(x, y, box) {
        return (x > box.left && x < (box.side + box.left)) && (y > box.top && y < (box.top + box.side));
      }

      function isCloseEnough(p1, p2) {
        return Math.abs(p1 - p2) < 20;
      }
    },
    mouseUp() {
      this.dragging = null;
      this.mouseOld = null;
      this.drawRectInCanvas();
      this.thumbnailDimensionsChanged();
    },
    mouseMove(event) {    
      this.updateMousePosition(event);
      if(this.dragging == null) return;

      event.preventDefault();
      event.stopPropagation();

      const diffX = this.mouse.x - this.mouseOld.x;
      const diffY = this.mouse.y - this.mouseOld.y;
      this.mouseOld = this.mouse;

      switch (this.dragging) {
        case 0: { // Entire box
          if (diffX) {
            this.selector.left += diffX;
            if (this.selector.left < 0) this.selector.left = 0;
            if (this.selector.left + this.selector.side > this.canvas.width)
              this.selector.left = this.canvas.width - this.selector.side;
          }

          if (diffY) {
            this.selector.top += diffY;
            if (this.selector.top < 0) this.selector.top = 0;
            if (this.selector.top + this.selector.side > this.canvas.height)
              this.selector.top = this.canvas.height - this.selector.side;
          }

          break;
        }
        case 1: { // Top left
          let newSide = this.selector.side + ((-diffX + -diffY) / 2);
          if(newSide / this.canvasRatio < this.minWidth)
            newSide = this.minWidth * this.canvasRatio;

          this.selector.left = this.selector.left + this.selector.side - newSide;
          this.selector.top = this.selector.side + this.selector.top - newSide;
          this.selector.side = newSide;

          break;
        }
        case 2: { // Top right
          let newSide = this.selector.side + ((diffX + -diffY) / 2);
          if(newSide / this.canvasRatio < this.minWidth)
            newSide = this.minWidth * this.canvasRatio;
          
          this.selector.top = this.selector.side + this.selector.top - newSide;
          this.selector.side = newSide;

          break;
        }
        case 3: { // Bottom left
          let newSide = this.selector.side + ((-diffX + diffY) / 2);
          if(newSide / this.canvasRatio < this.minWidth)
            newSide = this.minWidth * this.canvasRatio;

          this.selector.left = this.selector.left + this.selector.side - newSide;
          this.selector.side = newSide;

          break;
        }
        case 4: { // Bottom right
          let newSide = this.selector.side + ((diffX + diffY) / 2);
          if(newSide / this.canvasRatio < this.minWidth)
            newSide = this.minWidth * this.canvasRatio;
          
          this.selector.side = newSide;

          break;
        }
        default: {
          console.log("unknown resize handle");
        }
      }

      if(this.selector.left < 0) this.selector.left = 0;  // left boundary
      if(this.selector.top < 0) this.selector.top = 0;    // top boundary
      if(this.selector.left + this.selector.side > this.canvas.width)  // right boundary
        this.selector.side = this.canvas.width - this.selector.left;
      if(this.selector.top + this.selector.side > this.canvas.height)  // bottom boundary
        this.selector.side = this.canvas.height - this.selector.top;

      this.drawRectInCanvas();
    },
  }
};
</script>
