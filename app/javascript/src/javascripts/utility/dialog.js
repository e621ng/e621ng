export default class Dialog {

  id = 0;

  static _container = null;
  static containerWidth = 0;
  static containerHeight = 0;

  static _currentTimeout = null;

  /** Container to which all dialogs are appended */
  static get container () {
    if (this._container !== null) return this._container;

    this._container = $("<div id='dialog-container'>").appendTo("body");
    this.updateContainerDimensions();

    // Window dimension changes
    $(window).on("resize.dialog orientationchange.dialog", () => this.onUpdateContainerDimensions());

    // Fullscreen changes
    $(document).on("fullscreenchange webkitfullscreenchange mozfullscreenchange MSFullscreenChange", () => {
      if (this._currentTimeout) clearTimeout(this._currentTimeout);
      this._currentTimeout = setTimeout(this.onUpdateContainerDimensions, 100); // Small delay to ensure layout has settled
    });

    return this._container;
  }

  static updateContainerDimensions () {
    this.containerWidth = this._container.innerWidth() || 800;
    this.containerHeight = this._container.innerHeight() || 600;
  }

  /**
   * The event handler for autonomic container resizing.
   * Updates the container dimensions, cancels & resets the stored timeout reference (if set), & fires the `dialogContainer:resize` event if the dimensions changed.
   * Ignores the value of `this`.
   */
  static onUpdateContainerDimensions () {
    const priorWidth = Dialog.containerWidth, priorHeight = Dialog.containerHeight;
    Dialog.updateContainerDimensions();
    if (Dialog._currentTimeout) {
      clearTimeout(Dialog._currentTimeout); // Stops quickly toggling fullscreen causing trouble
      Dialog._currentTimeout = null;
    }
    if (priorWidth !== Dialog.containerWidth || priorHeight !== Dialog.containerHeight)
      $(window).trigger("dialogContainer:resize");
  }

  static normalizedPositionLabel = {
    "center": 0.5,
    "top":    0.0,
    "bottom": 1.0,
    "left":   0.0,
    "right":  1.0,
  };

  /**
   * Takes a string label or number and returns a normalized position value between 0 and 1.
   * @param {string|number} value The position label or number to resolve.
   * @returns {number} A normalized number reflecting the bounded value (or a fallback if given bad input).
   */
  static resolveToNormalizedPosition (value) {
    return Dialog.normalizedPositionLabel[value] || (typeof (value) === "number" ? Math.max(Math.min(value, 1), 0) : 0.5);
  }

  // #region Dialog z-stacking and focus management
  /** @type {Dialog[]} */
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

      dialog._setZIndex(index);
      index++;
    }
  }
  // #endregion Dialog z-stacking and focus management


  $dialog = null; // The main dialog element
  $element = null; // Content element attached to the dialog
  $title = null; // Title element in the header
  dialogWidth = 0;
  dialogHeight = 0;
  currentNormalizedPosition = [
    Dialog.normalizedPositionLabel["center"],
    Dialog.normalizedPositionLabel["center"],
  ];

  _priorPlacedX = null;
  get priorPlacedX () {
    if (typeof this._priorPlacedX !== "number")
      this._priorPlacedX = this.currentNormalizedPosition[0] * (Dialog.containerWidth - this.dialogWidth);
    return this._priorPlacedX;
  }

  _priorPlacedY = null;
  get priorPlacedY () {
    if (typeof this._priorPlacedY !== "number")
      this._priorPlacedY = this.currentNormalizedPosition[1] * (Dialog.containerHeight - this.dialogHeight);
    return this._priorPlacedY;
  }

  /**
   * Create a new dialog.
   * Parameters could be passed in via a data-attribute on the element as well.
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
        "aria-labelledby": `dialog-title-${this.id}`,
      })
      .appendTo(Dialog.container);

    // UI Elements
    const header = $("<div class='dialog-header'>").appendTo(this.$dialog);
    this.$title = $("<span>").attr("id", `dialog-title-${this.id}`).appendTo(header);
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

    if (params.title) this.$title.text(params.title);


    // Initial Position
    if (params.position) {
      const parts = params.position.trim().split(/\s+/);
      this.currentNormalizedPosition = [
        Dialog.resolveToNormalizedPosition(parts[0]),
        Dialog.resolveToNormalizedPosition(parts[1]),
      ];
    }

    // Width and height
    this.dialogWidth = params.width || this.$dialog.outerWidth() || 250;
    if (params.height) this.dialogHeight = params.height + 32; // Account for header height
    else this.dialogHeight = this.$dialog.outerHeight() || 200;

    this.recalculatePosition();

    $(window).on("dialogContainer:resize", { obj: this }, this.onResize);

    // Start open
    // Must be called after setting width/height and position
    if (params.startOpen) this.open();
  }

  /** Stop the rebinding. */
  onResize (e) { e.data.obj.recalculatePosition(); }

  /** Recalculate the dialog's position based on the given normalized position and the container size. */
  recalculatePosition () {
    const _max = {
      x: Dialog.containerWidth - this.dialogWidth,
      y: Dialog.containerHeight - this.dialogHeight,
    };

    const positionDef = [];
    if (this.isPinned) {
      // Don't use the normalized position, just track the last non-automatic placement & attempt to
      // match it; this will also slide back towards the desired position if the container is
      // expanding instead of contracting.
      positionDef[0] = this.priorPlacedX;
      positionDef[1] = this.priorPlacedY;
    } else {
      positionDef[0] = _max.x * this.currentNormalizedPosition[0];
      positionDef[1] = _max.y * this.currentNormalizedPosition[1];
    }

    const positionCoords = {
      left: Math.max(0, Math.min(positionDef[0], _max.x)),
      top:  Math.max(0, Math.min(positionDef[1], _max.y)),
    };

    this._updatePosition(positionCoords.left, positionCoords.top);
  }

  setTitle (html) {
    this.$title.html(html);
  }

  _setZIndex (z) {
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

  _xMin = null;
  _yMin = null;
  get xMin () { return (this._xMin == 0) ? this._xMin : (this._xMin ||= parseInt(this.$dialog.css("left"))); }
  get yMin () { return (this._yMin == 0) ? this._yMin : (this._yMin ||= parseInt(this.$dialog.css("top"))); }
  get xMax () { return this.xMin + this.dialogWidth; }
  get yMax () { return this.yMin + this.dialogHeight; }

  /**
   * Updates the CSS position & the according cached values.
   * @param {number} xMin The dialog box's left edge
   * @param {number} yMin The dialog box's top edge
   * @param {boolean} [placed=false] Was this manually placed? Default `false`.
   */
  _updatePosition (xMin, yMin, placed = false) {
    this._xMin = xMin;
    this._yMin = yMin;
    if (placed) {
      this._priorPlacedX = xMin;
      this._priorPlacedY = yMin;
    }
    this.$dialog.css({
      width: this.dialogWidth,
      height: this.dialogHeight,
      left: xMin,
      top: yMin,
    });
  }

  _isPinned = true;
  /** True if the dialog is currently pinned */
  get isPinned () { return this._isPinned; }
  /** If unpinned, will trigger an update */
  set isPinned (value) {
    if (this._isPinned !== value) {
      this._isPinned = value;
      if (!value) this.recalculatePosition();
    }
  }

  togglePin () { return this.isPinned = !this.isPinned; }

  /** Completely destroy the dialog and clean up all resources */
  destroy () {
    this.close(true);

    // Remove from dialog stack and index
    Dialog.dialogStack = Dialog.dialogStack.filter(id => id !== this.id);
    delete Dialog.dialogIndex[this.id];
    Dialog.resetFocus();

    // Remove DOM and clean up references
    $(window).off("dialogContainer:resize", this.onResize);
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
    const maxX = Dialog.containerWidth - this.dialogWidth;
    const maxY = Dialog.containerHeight - this.dialogHeight;

    // Keep dialog within container bounds
    newX = Math.max(0, Math.min(newX, maxX));
    newY = Math.max(0, Math.min(newY, maxY));

    // Update for next resize
    this.currentNormalizedPosition = [
      (maxX > 0 ? newX / maxX : 0),
      (maxY > 0 ? newY / maxY : 0),
    ];

    this._updatePosition(newX, newY, true);
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
