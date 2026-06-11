import * as Types from "@/components/autocomplete/Types";

export default class AutocompleteWidget {

  private static instances = new Set<AutocompleteWidget>();
  private static globalHandlersInitialized = false;

  private static initializeGlobalHandlers () {
    if (this.globalHandlersInitialized) return;

    const repositionAll = () => {
      AutocompleteWidget.instances.forEach(instance => {
        if (!instance.isOpen) return;
        instance.positionDropdown();
      });
    };

    window.addEventListener("scroll", repositionAll, { passive: true });
    window.addEventListener("resize", repositionAll, { passive: true });

    AutocompleteWidget.globalHandlersInitialized = true;
  }

  // ============================== //
  // ===== Class Attributes ======= //
  // ============================== //

  private input: HTMLInputElement;
  private searchFn: Types.SearchFunction;
  private insertFn: Types.InsertFunction;
  private renderFn: Types.RenderFunction;
  private selectedIndex = -1;
  private results: Types.AutocompleteItem[] = [];
  private justSelected = false;
  private query = "";

  private debounceTimer: number | null = null;
  private blurTimer: number | null = null;

  private dropdown: HTMLUListElement;
  private originalAutocomplete: string | null;


  // ============================== //
  // ======== Constructor ========= //
  // ============================== //

  constructor (input: HTMLInputElement, { searchFn, insertFn, renderFn }: Types.AutocompleteConfig) {
    AutocompleteWidget.initializeGlobalHandlers();
    AutocompleteWidget.instances.add(this);

    this.input = input;
    this.searchFn = searchFn;
    this.insertFn = insertFn;
    this.renderFn = renderFn;

    // Attach input
    this.originalAutocomplete = this.input.getAttribute("autocomplete");
    this.input.setAttribute("autocomplete", "off");

    // Create dropdown
    this.dropdown = document.createElement("ul");
    this.dropdown.className = "ui-autocomplete-dropdown";
    this.dropdown.style.display = "none";
    this.dropdown.setAttribute("role", "listbox");
    this.dropdown.setAttribute("aria-label", "Autocomplete results");
    document.body.appendChild(this.dropdown);

    // Bind events
    this.handleInput = this.handleInput.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleBlur = this.handleBlur.bind(this);
    this.handleFocus = this.handleFocus.bind(this);
    this.handleDropdownMousedown = this.handleDropdownMousedown.bind(this);
    this.handleDropdownClick = this.handleDropdownClick.bind(this);

    this.input.addEventListener("input", this.handleInput);
    this.input.addEventListener("keydown", this.handleKeydown);
    this.input.addEventListener("blur", this.handleBlur);
    this.input.addEventListener("focus", this.handleFocus);

    this.dropdown.addEventListener("mousedown", this.handleDropdownMousedown);
    this.dropdown.addEventListener("click", this.handleDropdownClick);
  }


  // ============================== //
  // ========= Public API ========= //
  // ============================== //

  /** Positions the dropdown below the input field, adjusting for scroll and viewport. */
  public positionDropdown () {
    const rect = this.input.getBoundingClientRect();
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;

    this.dropdown.style.position = "absolute";
    this.dropdown.style.left = (rect.left + scrollLeft) + "px";
    this.dropdown.style.top = (rect.bottom + scrollTop) + "px";
    this.dropdown.style.minWidth = rect.width + "px";
  }

  private _isOpen = false;

  /** @returns Whether the autocomplete dropdown is currently open. */
  public get isOpen () { return this._isOpen; }

  public set isOpen (value: boolean) {
    if (value) {
      if (this._isOpen) return;
      this._isOpen = true;
      this.positionDropdown();
      this.dropdown.style.display = "block";
      this.input.setAttribute("aria-expanded", "true");
    } else {
      if (!this._isOpen) return;
      this._isOpen = false;
      this.dropdown.style.display = "none";
      this.input.setAttribute("aria-expanded", "false");
    }
  }

  /** Opens the autocomplete dropdown, making it visible and positioning it correctly. */
  public open () { this.isOpen = true; }

  /** Closes the autocomplete dropdown, hiding it from view and resetting selection state. */
  public close () { this.isOpen = false; }

  /**
   * Destroys the autocomplete widget, removing event listeners, DOM elements, and restoring original input state.
   * After calling this method, the instance should not be used.
   */
  public destroy () {
    this.close();
    clearTimeout(this.debounceTimer);

    // Unbind events
    this.input.removeEventListener("input", this.handleInput);
    this.input.removeEventListener("keydown", this.handleKeydown);
    this.input.removeEventListener("blur", this.handleBlur);
    this.input.removeEventListener("focus", this.handleFocus);

    this.dropdown.removeEventListener("mousedown", this.handleDropdownMousedown);
    this.dropdown.removeEventListener("click", this.handleDropdownClick);

    // Detach input
    if (this.originalAutocomplete !== null)
      this.input.setAttribute("autocomplete", this.originalAutocomplete);
    else this.input.removeAttribute("autocomplete");

    // Destroy dropdown
    if (this.dropdown && this.dropdown.parentNode)
      this.dropdown.remove();

    AutocompleteWidget.instances.delete(this);
  }


  // ============================== //
  // ====== Event Listeners ======= //
  // ============================== //

  /**
   * Handles input events with debouncing to limit search frequency.
   */
  private handleInput () {
    if (this.justSelected) {
      this.justSelected = false;
      return;
    }

    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.search();
    }, 225);
  }

  /**
   * Handles keydown events for navigation and selection within the dropdown.
   * @param event The keyboard event triggered on keydown.
   */
  private handleKeydown (event: KeyboardEvent) {
    if (!this.isOpen) return;

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();

        if (this.selectedIndex < this.results.length - 1)
          this.setSelected(this.selectedIndex + 1);
        else this.setSelected(-1);

        break;
      case "ArrowUp":
        event.preventDefault();

        if (this.selectedIndex > 0)
          this.setSelected(this.selectedIndex - 1);
        else if (this.selectedIndex === 0)
          this.setSelected(-1);
        else this.setSelected(this.results.length - 1);

        break;
      case "Enter":
        if (this.selectedIndex >= 0) {
          event.preventDefault();
          event.stopPropagation();

          this.selectItem(this.results[this.selectedIndex]);
        }
        break;
      case "Escape":
        event.preventDefault();
        this.close();
        break;
      case "Tab":
        if (this.results.length > 0) {
          event.preventDefault();

          if (this.selectedIndex >= 0)
            this.selectItem(this.results[this.selectedIndex]);
          else this.selectItem(this.results[0]);
        }
        break;
    }
  }

  /**
   * Handles blur events to close the dropdown after a short delay, allowing click events to register.
   */
  private handleBlur () {
    clearTimeout(this.blurTimer);
    this.blurTimer = setTimeout(() => {
      this.close();
    }, 150);
  }

  /**
   * Handles focus events to clear any pending blur timers, keeping the dropdown open if the input regains focus.
   */
  private handleFocus () {
    clearTimeout(this.blurTimer);
  }

  /**
   * Handles mousedown events on the dropdown to prevent it from losing focus when clicking inside, allowing item selection to work properly.
   * @param event The mouse event triggered on mousedown.
   */
  private handleDropdownMousedown (event: MouseEvent) {
    event.preventDefault();
  }

  /**
   * Handles click events on the dropdown to select an item.
   * @param event The mouse event triggered on click.
   */
  private handleDropdownClick (event: MouseEvent) {
    const item = (event.target as HTMLElement).closest("li");
    if (item) {
      const index = Array.from(this.dropdown.children).indexOf(item);
      if (index >= 0 && this.results[index]) {
        this.selectItem(this.results[index]);
      }
    }
  }


  // ============================== //
  // ======= Class Methods ======== //
  // ============================== //

  /** Performs the search using the provided search function, updates results, and manages dropdown state accordingly. */
  private async search () {
    const currentQuery = this.input.value;

    if (!currentQuery.trim()) {
      this.results = [];
      this.selectedIndex = -1;
      this.query = "";
      this.render();
      this.close();
      return;
    }

    if (currentQuery.trim() === this.query.trim()) return;

    this.query = currentQuery;

    try {
      const results = await this.searchFn(this.query, this.input);

      if (this.query !== currentQuery) return;

      let newSelectedIndex = -1;
      if (this.selectedIndex >= 0 && this.selectedIndex < this.results.length) {
        const currentSelectedItem = this.results[this.selectedIndex];
        newSelectedIndex = results.findIndex(item => item.name === currentSelectedItem.name);
      }

      this.results = results;
      this.selectedIndex = newSelectedIndex;
      this.render();

      if (this.results.length > 0) {
        this.open();
      } else {
        this.close();
      }
    } catch (error) {
      console.error("Autocomplete search error:", error);
      this.results = [];
      this.selectedIndex = -1;
      this.render();
      this.close();
    }
  }

  /** Renders the dropdown list based on the current search results. */
  private render () {
    this.dropdown.innerHTML = "";

    this.results.forEach((item, index) => {
      const li = document.createElement("li");
      li.setAttribute("role", "option");
      li.setAttribute("aria-selected", "false");
      li.setAttribute("data-index", index + "");

      this.renderFn(li, item);

      this.dropdown.appendChild(li);
    });

    if (this.selectedIndex >= 0 && this.selectedIndex < this.results.length) {
      this.setSelected(this.selectedIndex);
    }
  }

  /**
   * Updates the selected index and applies appropriate ARIA attributes and CSS classes to reflect the current selection in the dropdown.
   * @param index The index of the item to select.
   */
  private setSelected (index: number) {
    const items = this.dropdown.querySelectorAll("li");
    items.forEach(item => {
      item.setAttribute("aria-selected", "false");
      item.classList.remove("selected");
    });

    this.selectedIndex = index;

    if (index >= 0 && index < items.length) {
      const item = items[index];
      item.setAttribute("aria-selected", "true");
      item.classList.add("selected");

      item.scrollIntoView({ block: "nearest" });
    }
  }

  /**
   * Handles the selection of an autocomplete item, invoking the insert function and closing the dropdown.
   * @param item The autocomplete item that was selected.
   */
  private selectItem (item: Types.AutocompleteItem) {
    this.justSelected = true;
    this.insertFn(this.input, item.name);
    this.close();
    this.input.focus();
  }
}
