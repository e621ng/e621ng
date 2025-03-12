const ModAction = {
  init () {
    const actionSelect = document.getElementById("search_action");
    const fieldsDataElement = document.getElementById("mod-action-fields-data");
    const formElement = document.querySelector("#searchform > form");

    if (!actionSelect || !fieldsDataElement || !formElement) {
      return;
    }

    const knownActions = JSON.parse(fieldsDataElement.textContent);
    const urlParams = new URLSearchParams(window.location.search);

    function createField (name) {
      const wrapper = document.createElement("div");
      wrapper.classList.add("input", "string", "optional", `search_${name}`);
      wrapper.dataset.dynamicField = "true";

      const label = document.createElement("label");
      label.textContent = name.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
      label.setAttribute("for", `search_${name}`);

      const input = document.createElement("input");
      input.name = `search[${name}]`;
      input.id = `search_${name}`;
      input.type = "text";

      if (urlParams.has(`search[${name}]`)) {
        input.value = urlParams.get(`search[${name}]`);
      }

      wrapper.appendChild(label);
      wrapper.appendChild(input);
      return wrapper;
    }

    function updateFields () {
      formElement.querySelectorAll("[data-dynamic-field]").forEach((el) => el.remove());

      const selectedAction = actionSelect.value;
      if (knownActions[selectedAction]) {
        knownActions[selectedAction].forEach((key) => {
          const field = createField(key);
          actionSelect.parentElement.insertAdjacentElement("afterend", field);
        });
      }
    }

    actionSelect.addEventListener("change", updateFields);
    updateFields();
  },
};

$(document).ready(function () {
  ModAction.init();
});

export default ModAction;
