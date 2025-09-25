export default class Dialog {

  // Container to which all dialogs are appended
  static _container = null;
  static containerWidth = 0;
  static containerHeight = 0;
  static get container () {
    if (this._container !== null) return this._container;

    this._container = $("<div id='dialog-container'>").appendTo("body");
    this.updateContainerDimensions();

    // Window dimension changes
    $(window).on("resize orientationchange", () => this.updateContainerDimensions());

    // Fullscreen changes
    $(document).on("fullscreenchange webkitfullscreenchange mozfullscreenchange MSFullscreenChange", () => {
      setTimeout(() => this.updateContainerDimensions(), 100); // Small delay to ensure layout has settled
    });

    return this._container;
  }

  static updateContainerDimensions () {
    this.containerWidth = this._container.innerWidth() || 800;
    this.containerHeight = this._container.innerHeight() || 600;
  }

  static positionDefinitions = {
    "top":    { "left": [0, 0], "center": [0.5, 0], "right": [1, 0] },
    "center": { "left": [0, 0.5], "center": [0.5, 0.5], "right": [1, 0.5] },
    "bottom": { "left": [0, 1], "center": [0.5, 1], "right": [1, 1] },
    "left":   { "top": [0, 0], "center": [0, 0.5], "bottom": [0, 1] },
    "right":  { "top": [1, 0], "center": [1, 0.5], "bottom": [1, 1] },
  };

  // Dialog z-stacking and focus management
  static dialogStack = [];
  static dialogIndex = {};
  static dialogCount = 0;

  /** Bring the specified dialog to the front and update the stacking order. */
  static focusDialog (current) {
    // Skip if already on top
    const currentIndex = this.dialogStack.indexOf(current.id);
    if (currentIndex === this.dialogStack.length - 1) return;

    // Add to end (top)
    if (currentIndex > -1)
      this.dialogStack.splice(currentIndex, 1);
    this.dialogStack.push(current.id);
    this.resetFocus();
  }

  /** Reset the z-index of all dialogs based on their order in the stack. */
  static resetFocus () {
    let index = 0;
    for (const dialogID of this.dialogStack) {
      const dialog = this.dialogIndex[dialogID];
      if (!dialog) continue;

      dialog.setZIndex(index);
      index++;
    }
  }


  $dialog = null; // The main dialog element
  $element = null; // Content element attached to the dialog
  dialogWidth = 0;
  dialogHeight = 0;
  initialPosition = ["center", "center"];
  id = 0;

  /**
   * Create a new dialog.
   * Parmeters could be passed in via a data-attribute on the element as well.
   * @param {JQuery<HTMLElement> | string} element Either a jQuery element or a selector string for the dialog content.
   * @param {any} params Configuration parameters.
   *   - title: Title text for the dialog header.
   *   - position: Initial position of the dialog (e.g., "top left", "center center").
   *   - width: Width of the dialog in pixels.
   *   - height: Height of the dialog in pixels.
   *   - startOpen: Whether to open the dialog immediately upon creation.
   */
  constructor (element, params = {}) {
    this.$element = (typeof element === "string") ? $(element) : element;
    this.$dialog = $("<div class='dialog hidden'>")
      .attr({
        "role": "dialog",
        "tabindex": "-1",
      })
      .appendTo(Dialog.container);

    // UI Elements
    const header = $("<div class='dialog-header'>").appendTo(this.$dialog);
    header.on("mousedown", (event) => this.startDrag(event));

    $("<button type='button' class='st-button'>&times;</button>")
      .attr({
        "type": "button",
        "title": "Close",
        "aria-label": "Close dialog",
      })
      .appendTo(header)
      .on("click", () => this.close());

    $("<div class='dialog-content'>")
      .attr("role", "document")
      .appendTo(this.$dialog)
      .append(this.$element);

    // Focus management
    this.id = Dialog.dialogCount++;
    Dialog.dialogIndex[this.id] = this;
    Dialog.dialogStack.push(this.id);
    this.$dialog.on("mousedown", () => { Dialog.focusDialog(this); });
    Dialog.resetFocus(this);

    // Keyboard accessibility
    this.$dialog.on("keydown", (event) => {
      if (event.key !== "Escape" && event.keyCode !== 27) return;
      event.preventDefault();
      this.close();
    });


    // === Parameters ===
    const data = this.$element.data();
    for (const key in data) // Load from data-attributes
      if (params[key] === undefined) params[key] = data[key];

    if (params.title) {
      $("<span>")
        .text(params.title)
        .attr("id", `dialog-title-${this.id}`)
        .prependTo(header);
      this.$dialog.attr("aria-labelledby", `dialog-title-${this.id}`);
    } else this.$dialog.attr("aria-label", "Dialog");

    // Set modal behavior if specified
    if (params.modal) {
      this.$dialog.attr("aria-modal", "true");
    }


    // Initial Position
    if (params.position) {
      const parts = params.position.trim().split(/\s+/);
      this.initialPosition = [
        parts[0] || "center",
        parts[1] || "center",
      ];
    }

    // Width and height
    this.dialogWidth = params.width || this.$dialog.outerWidth() || 250;
    if (params.height) this.dialogHeight = params.height + 32; // Account for header height
    else this.dialogHeight = this.$dialog.outerHeight() || 200;

    this.recalculatePosition();

    // Start open
    // Must be called after setting width/height and position
    if (params.startOpen) this.open();
  }

  /** Recalculate the dialog's position based on its initial position and the container size. */
  recalculatePosition () {
    const [horizontal, vertical] = this.initialPosition;
    const positionDef = Dialog.positionDefinitions[horizontal]?.[vertical] || [0.5, 0.5];

    const positionCoords = {
      left: Math.max(0, Math.min(
        (Dialog.containerWidth - this.dialogWidth) * positionDef[0],
        Dialog.containerWidth - this.dialogWidth,
      )),
      top: Math.max(0, Math.min(
        (Dialog.containerHeight - this.dialogHeight) * positionDef[1],
        Dialog.containerHeight - this.dialogHeight,
      )),
    };

    this.$dialog.css({
      width: this.dialogWidth,
      height: this.dialogHeight,
      left: positionCoords.left,
      top: positionCoords.top,
    });
  }

  setZIndex (z) {
    this.$dialog.css("z-index", 250 + z);
  }

  // ========================= //
  // ==== Utility Methods ==== //
  // ========================= //

  _isOpen = false;

  /** True if the dialog is currently open */
  get isOpen () { return this._isOpen; }
  set isOpen (value) {
    if (value) this.open();
    else this.close();
  }


  /** Make the dialog visible */
  open () {
    this._isOpen = true;
    this.$dialog.removeClass("hidden");

    Dialog.focusDialog(this); // z-index stacking
    this.$dialog.focus(); // actual focus for accessibility

    this.$element.trigger("dialog:open");
  }

  /** Hide the dialog from view */
  close (quiet = false) {
    this._isOpen = false;

    // Clean up any active drag state
    if (this.isDragging) {
      this.isDragging = false;

      if (this.dragAnimationFrame) {
        cancelAnimationFrame(this.dragAnimationFrame);
        this.dragAnimationFrame = null;
      }

      $(document).off("mousemove.dialog-drag mouseup.dialog-drag visibilitychange.dialog-drag");
      $(window).off("blur.dialog-drag");
      this.$dialog.removeClass("dragging");
    }

    this.$dialog.addClass("hidden").removeClass("focused");
    if (!quiet) this.$element.trigger("dialog:close");
  }

  /** Toggle the dialog's visibility */
  toggle () {
    if (this.isOpen) this.close();
    else this.open();
  }

  /** Completely destroy the dialog and clean up all resources */
  destroy () {
    this.close(true);

    // Remove from dialog stack and index
    Dialog.dialogStack = Dialog.dialogStack.filter(id => id !== this.id);
    delete Dialog.dialogIndex[this.id];
    Dialog.resetFocus();

    // Remove DOM and clean up references
    this.$element.trigger("dialog:destroy");
    this.$dialog.remove();
    this.$dialog = null;
    this.$element = null;
  }


  // ========================= //
  // ==== Dragging Methods === //
  // ========================= //

  isDragging = false;
  dragStartX = 0;
  dragStartY = 0;
  dialogStartX = 0;
  dialogStartY = 0;
  dragAnimationFrame = null;

  /** Start dragging the dialog */
  startDrag (event) {
    if (event.which !== 1) return; // Only handle left mouse button
    if ($(event.target).is("button")) return; // Don't drag if clicking on the close button

    event.preventDefault();
    this.$dialog.addClass("dragging");

    this.isDragging = true;
    this.dragStartX = event.clientX;
    this.dragStartY = event.clientY;

    const dialogPosition = this.$dialog.position();
    this.dialogStartX = dialogPosition.left;
    this.dialogStartY = dialogPosition.top;

    // Mouse listeners for dragging
    $(document).on("mousemove.dialog-drag", (event) => this.drag(event));
    $(document).on("mouseup.dialog-drag", () => this.stopDrag());

    // Dragging interrupted: tab switch, window blur, etc.
    $(window).on("blur.dialog-drag", () => this.stopDrag());
    $(document).on("visibilitychange.dialog-drag", () => {
      if (document.hidden) this.stopDrag();
    });
  }

  /** Handle dragging motion */
  drag (event) {
    if (!this.isDragging) return;

    // Throttle drag updates
    if (this.dragAnimationFrame) cancelAnimationFrame(this.dragAnimationFrame);
    this.dragAnimationFrame = requestAnimationFrame(() => {
      this.updateDialogPosition(event);
      this.dragAnimationFrame = null;
    });
  }

  /** Update the dialog position during drag */
  updateDialogPosition (event) {
    event.preventDefault();

    let newX = this.dialogStartX + (event.clientX - this.dragStartX);
    let newY = this.dialogStartY + (event.clientY - this.dragStartY);

    // Keep dialog within container bounds
    newX = Math.max(0, Math.min(newX, Dialog.containerWidth - this.dialogWidth));
    newY = Math.max(0, Math.min(newY, Dialog.containerHeight - this.dialogHeight));

    this.$dialog.css({
      left: newX,
      top: newY,
    });
  }

  /** Stop dragging the dialog */
  stopDrag () {
    if (!this.isDragging) return;
    this.isDragging = false;

    // Cancel any pending animation frame
    if (this.dragAnimationFrame) {
      cancelAnimationFrame(this.dragAnimationFrame);
      this.dragAnimationFrame = null;
    }

    $(document).off("mousemove.dialog-drag mouseup.dialog-drag visibilitychange.dialog-drag");
    $(window).off("blur.dialog-drag");
    this.$dialog.removeClass("dragging");
  }
}
