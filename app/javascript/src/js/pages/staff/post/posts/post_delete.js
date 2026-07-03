import Utility from "@/utility/utility";

let PostDeletion = {};

PostDeletion.init = function () {
  const input = $("#reason");
  let inputVal = input.val() + "";

  // #region DMail Notification
  /** @type {HTMLInputElement} */
  const dMailCheckBox = document.querySelector("input#send-dmail"),
    /** @type {HTMLSelectElement} */
    dMailTemplate = document.querySelector("select#del-dmail-template"),
    /** @type {HTMLElement} */
    dMailMessage = document.querySelector("label[for=send-dmail] ~ .dtext-formatter"),
    /** @type {JQuery<HTMLInputElement>} */
    dMailTitleInput = $(document.querySelector("#dmail-title")),
    /** @type {JQuery<HTMLTextAreaElement>} */
    dMailTextArea = $(document.querySelector("#dmail-message"));
  let updateDMailReason = null;
  // Absent if no DMail template is configured
  if (dMailCheckBox && dMailTemplate && dMailMessage && dMailTitleInput && dMailTextArea) {
    const updateDMailActivation = function () {
      if (dMailCheckBox.checked) {
        dMailMessage.style.display = dMailTitleInput[0].style.display = dMailTemplate.parentElement.style.display = "";
        dMailTitleInput.removeAttr("disabled");
        dMailTextArea.removeAttr("disabled");
      } else {
        dMailMessage.style.display = dMailTitleInput[0].style.display = dMailTemplate.parentElement.style.display = "none";
        dMailTitleInput.attr("disabled", "disabled");
        dMailTextArea.attr("disabled", "disabled");
      }
    };
    updateDMailReason = function (force = false) {
      const newReason = input.val()?.toString();
      let newTitle = dMailTemplate.selectedOptions[0].getAttribute("data-dmail-title");
      let newMessage = dMailTemplate.value;
      // Don't overwrite the input's text unless necessary
      let titleChanged = force, messageChanged = force;
      if (!Utility.blank(newReason)) {
        const reasonPlaceholder = "%REASON%";
        if (newTitle.indexOf(reasonPlaceholder) >= 0) {
          newTitle = newTitle.replaceAll(reasonPlaceholder, newReason);
          titleChanged = true;
        }
        if (newMessage.indexOf(reasonPlaceholder) >= 0) {
          newMessage = newMessage.replaceAll(reasonPlaceholder, newReason);
          messageChanged = true;
        }
      }
      if (titleChanged) {
        dMailTitleInput.val(newTitle);
      }
      if (messageChanged) {
        dMailTextArea.val(newMessage);
      }
    };
    dMailCheckBox.addEventListener("click", () => updateDMailActivation());
    dMailTemplate.addEventListener("change", () => updateDMailReason(true));
    updateDMailActivation();
    updateDMailReason(true);
  }
  // #endregion DMail Notification

  // #region Delete Reason
  const buttons = $("a.delreason-button")
    .on("click", (event) => {
      event.stopPropagation();
      event.preventDefault();

      const $button = $(event.target);
      if (!$button.is("a")) return;

      const text = $button.data("processed");
      input.val((index, current) => {
        current = current.trim();
        if ($button.hasClass("enabled")) {
          return current
            .replace(text, "")
            .replace(/ \/ $|^ \/ /g, "") // trim leading and trailing slashes
            .replace(/( \/ ){2,}/g, " / "); // trim duplicate / leftover slashes
        } else return (current ? current + " / " : "") + text;
      });
      input.trigger("input");
    })
    .on("e621:refresh", (event) => {
      const $button = $(event.target);
      let text = $button.data("text");
      for (const buttonInput of $button.find("input[type=text]"))
        text = text.replace("%ID%", $(buttonInput).val());

      $button.data("processed", text);
      $button.toggleClass("enabled", inputVal.indexOf(text) >= 0);
    })
    .each((index, element) => {
      const $button = $(element);
      $button.find("input[type=text]").on("input", () => {
        $button.trigger("e621:refresh");
      });
    });
  buttons.trigger("e621:refresh");

  input.on("input", () => {
    inputVal = input.val() + "";
    buttons.trigger("e621:refresh");
    updateDMailReason?.();
  });

  $("#delreason-clear").on("click", () => {
    input.val("").trigger("input");
  });
  // #endregion Delete Reason
};

$(function () {
  if ($("div#c-confirm-delete").length)
    PostDeletion.init();
});

export default PostDeletion;
