import Cookie from "./cookie";

const FursonaCheck = {
  init () {
    const $container = $(".fursona-check");
    const $startBtn = $("#start-drawing");
    const $submitBtn = $("#submit-fursona");
    const $colorPicker = $(".color-picker");
    const $brushPicker = $(".brush-picker");
    const $eraser = $("#eraser");
    const $canvas = $("#fursona-canvas");
    const $drawingArea = $("#drawing-area");
    const $submissionInfo = $("#submission-info");
    const $submissionDone = $("#submission-done");
    const $downloadFursona = $("#download-fursona");
    const $closeDialog = $("#close-dialog");
    const $undoBtn = $("#undo");

    const canvas = $canvas[0];
    const ctx = canvas.getContext("2d");
    const gw = Cookie.get("fursona-check");

    if (gw === "confirmed" || $("#a-terms-of-service").length > 0) {
      return;
    }

    $container.show();

    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    let currentColor = "#000";
    let eraserMode = false;

    const colors = [
      "#000000",
      "#D72638",
      "#F49D37",
      "#FFC800",
      "#38B000",
      "#009FFD",
      "#8438FF",
      "#D100D1",
      "#FFFFFF",
    ];

    colors.forEach((color) => {
      const $colorDiv = $("<div class='color-option drawing-button'></div>")
        .css({ backgroundColor: color })
        .attr("data-color", color)
        .on("click", function () {
          $(".color-option").removeClass("selected");
          $(this).addClass("selected");

          eraserMode = false;
          currentColor = $(this).data("color");
          updateBrushDotColors(currentColor);
        });

      $colorPicker.append($colorDiv);
    });

    $colorPicker.children().first().addClass("selected");

    $eraser.addClass("drawing-button").addClass("color-option");
    $eraser.on("click", function () {
      $(".color-option").removeClass("selected");
      $eraser.addClass("selected");

      eraserMode = true;
      currentColor = "#FFFFFF";
      updateBrushDotColors("#000");
    });

    let undoStack = [];

    $undoBtn.addClass("drawing-button");
    $undoBtn.on("click", function () {
      if (undoStack.length > 0) {
        ctx.putImageData(undoStack.pop(), 0, 0);
      }
    });

    function saveState () {
      undoStack.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
      if (undoStack.length > 10) {
        undoStack.shift();
      }
    }

    const brushSizes = { small: 3, medium: 5, large: 10 };
    let brushSize = brushSizes.medium;

    Object.entries(brushSizes).forEach(([label, size]) => {
      const $brushContainer = $("<div class='brush-size drawing-button'></div>")
        .attr("data-size", size)
        .attr("data-label", label)
        .on("click", function () {
          $(".brush-size").removeClass("selected");
          $(this).addClass("selected");
          brushSize = $(this).data("size");
        });

      const $brushDot = $("<div></div>").addClass(`brush-dot brush-${label}`);
      $brushContainer.append($brushDot);
      $brushPicker.append($brushContainer);
    });

    $brushPicker.children().eq(1).addClass("selected");

    function updateBrushDotColors (color) {
      $(".brush-dot").css("background-color", eraserMode ? "#000" : color);
    }

    let drawing = false;
    let lastX = 0;
    let lastY = 0;

    function _unscroll (e) {
      e.preventDefault();
    }

    function stopDrawing () {
      drawing = false;
      ctx.beginPath();
      window.removeEventListener("touchmove", _unscroll);
    }

    function drawLine (x, y) {
      ctx.strokeStyle = currentColor;
      ctx.lineWidth = brushSize * 2;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";

      ctx.beginPath();
      ctx.moveTo(lastX, lastY);
      ctx.lineTo(x, y);
      ctx.stroke();

      lastX = x;
      lastY = y;
    }

    function getCanvasPos (event) {
      const rect = canvas.getBoundingClientRect();
      return {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
      };
    }

    canvas.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      saveState();

      window.addEventListener("touchmove", _unscroll, { passive: false });

      drawing = true;
      const { x, y } = getCanvasPos(event);
      lastX = x;
      lastY = y;

      ctx.beginPath();
      ctx.arc(lastX, lastY, brushSize, 0, Math.PI * 2);
      ctx.fillStyle = currentColor;
      ctx.fill();

      ctx.beginPath();
      ctx.moveTo(lastX, lastY);
    });

    window.addEventListener("pointerup", stopDrawing);

    window.addEventListener("pointermove", (event) => {
      if (!drawing) return;

      const { x, y } = getCanvasPos(event);
      if (x < 0 || x > canvas.width || y < 0 || y > canvas.height) {
        lastX = x;
        lastY = y;
        return;
      }

      drawLine(x, y);
    });

    $startBtn.on("click", function () {
      $startBtn.hide();
      $drawingArea.show();
      $submitBtn.show();
    });

    $submitBtn.on("click", function () {
      Cookie.put("fursona-check", "confirmed");

      $drawingArea.hide();
      $submissionInfo.hide();
      $submitBtn.hide();

      $submissionDone.show();
      $downloadFursona.show();
      $closeDialog.show();
    });

    $downloadFursona.on("click", function () {
      const link = document.createElement("a");
      link.download = Danbooru.User.name + "-fursona-verification.png";
      link.href = canvas.toDataURL();
      link.click();
    });

    $closeDialog.on("click", function () {
      $container.hide();
    });
  },
};

$(document).ready(() => FursonaCheck.init());

export default FursonaCheck;
