// Takedown editor functionality for managing post approval/deletion
class TakedownEditor {
  constructor (takedownId) {
    this.takedownId = takedownId;
    this.init();
  }

  init () {
    this.bindEvents();
    this.updateStatusText();
    // Trigger change event for existing checkboxes to run their update handlers
    document.querySelectorAll("[id^=\"takedown_posts_\"]").forEach(checkbox => {
      checkbox.dispatchEvent(new Event("change"));
    });
  }

  bindEvents () {
    // Handle checkbox changes
    document.body.addEventListener("change", (event) => {
      if (event.target.id && event.target.id.startsWith("takedown_posts_")) {
        this.handlePostCheckboxChange(event.target);
      }
    });

    // Delete all button
    const deleteAllBtn = document.getElementById("takedown-deleteall");
    if (deleteAllBtn) {
      deleteAllBtn.addEventListener("click", () => {
        document.querySelectorAll("[id^=\"takedown_posts_\"]").forEach(checkbox => {
          checkbox.checked = true;
          checkbox.dispatchEvent(new Event("change"));
        });
      });
    }

    // Keep all button
    const keepAllBtn = document.getElementById("takedown-keepall");
    if (keepAllBtn) {
      keepAllBtn.addEventListener("click", () => {
        document.querySelectorAll("[id^=\"takedown_posts_\"]").forEach(checkbox => {
          checkbox.checked = false;
          checkbox.dispatchEvent(new Event("change"));
        });
      });
    }

    // Remove post buttons
    document.body.addEventListener("click", (event) => {
      if (event.target.classList.contains("takedown-post-remove")) {
        const postId = event.target.parentElement.dataset.postId;
        Danbooru.Takedown.remove_post(this.takedownId, postId);
      }
    });

    // Add posts by tags input
    const tagsInput = document.getElementById("takedown-add-posts-tags");
    if (tagsInput) {
      tagsInput.addEventListener("keyup", (e) => {
        const previewBtn = document.getElementById("takedown-add-posts-tags-preview");
        if (previewBtn) {
          previewBtn.disabled = e.target.value.length === 0;
        }
      });

      tagsInput.addEventListener("keydown", (e) => {
        if (e.keyCode === 13) {
          const previewBtn = document.getElementById("takedown-add-posts-tags-preview");
          if (previewBtn && !previewBtn.disabled) {
            previewBtn.click();
          }
          e.preventDefault();
          return false;
        }
      });
    }

    // Add posts by IDs input
    const idsInput = document.getElementById("takedown-add-posts-ids");
    if (idsInput) {
      idsInput.addEventListener("keyup", (e) => {
        const submitBtn = document.getElementById("takedown-add-posts-ids-submit");
        if (submitBtn) {
          submitBtn.disabled = e.target.value.length === 0;
        }
      });

      idsInput.addEventListener("keydown", (e) => {
        if (e.keyCode === 13) {
          const submitBtn = document.getElementById("takedown-add-posts-ids-submit");
          if (submitBtn && !submitBtn.disabled) {
            submitBtn.click();
          }
          e.preventDefault();
          return false;
        }
      });
    }
  }

  handlePostCheckboxChange (checkbox) {
    // Update labels when checkboxes are changed
    const label = document.querySelector(`label[for="${checkbox.id}"]`);
    if (label) {
      const span = label.querySelector("span");
      if (checkbox.checked) {
        label.classList.remove("takedown-post-keep");
        label.classList.add("takedown-post-delete");
        if (span) span.innerHTML = "Delete";
      } else {
        label.classList.remove("takedown-post-delete");
        label.classList.add("takedown-post-keep");
        if (span) span.innerHTML = "Keep";
      }
    }

    this.updateStatusText();
  }

  updateStatusText () {
    // Update text next to status dropdown based on kept/deleted post count
    const keptCount = document.querySelectorAll("label.takedown-post-keep").length;
    const deletedCount = document.querySelectorAll("label.takedown-post-delete").length;
    const statusElement = document.getElementById("post-status-select");

    if (statusElement) {
      if (keptCount === 0) {
        // None are kept, so takedown status will be 'approved'
        statusElement.innerHTML = "Status will be set to Approved";
      } else if (deletedCount === 0) {
        // None are deleted, so takedown status will be 'denied'
        statusElement.innerHTML = "Status will be set to Denied";
      } else {
        // Some kept, some deleted, so takedown status will be 'partial'
        statusElement.innerHTML = "Status will be set to Partially Approved";
      }
    }
  }
}

// Auto-initialize when the page loads
document.addEventListener("DOMContentLoaded", function () {
  // Check if we're on a takedown editor page
  const takedownIdElement = document.querySelector("[data-takedown-id]");
  if (takedownIdElement) {
    const takedownId = takedownIdElement.dataset.takedownId;
    new TakedownEditor(takedownId);
  }
});

export default TakedownEditor;
