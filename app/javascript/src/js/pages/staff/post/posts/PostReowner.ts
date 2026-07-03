import E621Type from "@/interfaces/E621";
import Post from "@/pages/posts/posts";
import TaskQueue from "@/utility/TaskQueue";
import Dialog from "@/utility/dialog";

declare const E621: E621Type;

interface PreviousOwner {
  id: number;
  name: string;
}

interface ApiResponseError {
  responseJSON?: {
    errors?: string[];
    reason?: string;
  };
}

export default class PostReowner {
  static initialize_links (): void {
    let reownerDialog: Dialog | null = null;

    $("#reowner-post-link").on("click", async (e: JQuery.ClickEvent) => {
      e.preventDefault();

      const postId = $("meta[name=post-id]").attr("content") as string;

      const previousOwnersPromise: Promise<PreviousOwner[]> = PostReowner.previous_owners(postId);

      const form = $("#reowner-dialog");
      const reownerStatus = $("#reowner-dialog-status");
      const reownerSelect = $("#reowner-dialog-select");
      const reownerInput = $("#reowner-dialog-input");
      const reownerReownerVersions = $("#reowner-dialog-reowner-versions");
      const reownerPostEvents = $("#reowner-dialog-post-events");
      const reownerOkButton = $("#reowner-dialog-ok");

      const inputElement = reownerInput[0] as HTMLInputElement;
      const selectElement = reownerSelect[0] as HTMLSelectElement;
      const okButtonElemnent = reownerOkButton[0] as HTMLButtonElement;

      // Until the previous owner list is loaded
      reownerStatus.text("Loading...");
      inputElement.style.display = "none";
      selectElement.style.display = "none";
      okButtonElemnent.disabled = true;

      const toggleOkButton = (): void => {
        const newOwner = reownerInput.val() as string | undefined;
        const hasNewOwner = (newOwner?.trim() || "").length > 0;
        okButtonElemnent.disabled = !hasNewOwner;
      };

      reownerInput.on("input", toggleOkButton);

      const updateReownerInput = (selectValue: string): void => {
        if (selectValue === "0") {
          inputElement.disabled = false;
          inputElement.style.display = "";
          reownerInput.val("");
        } else {
          inputElement.disabled = true;
          inputElement.style.display = "none";
          if (selectValue) {
            reownerInput.val(`!${selectValue}`);
          }
        }
        toggleOkButton();
      };

      if (reownerDialog === null) {
        reownerDialog = new Dialog("#reowner-dialog", { width: 250 });

        reownerSelect.on("change", (event: JQuery.ChangeEvent) => {
          const target = event.target as HTMLSelectElement;
          updateReownerInput(target.value);
        });

        $("#reowner-dialog-cancel").on("click", () => reownerDialog?.close());

        $(document).on("keydown", (event: JQuery.KeyDownEvent) => {
          // .isFocused would make more sense if it existed
          if (event.key === "Enter" && reownerDialog?.isOpen) {
            event.preventDefault();
            form.trigger("submit");
          }
        });
      }

      form.off("submit").on("submit", (event: JQuery.SubmitEvent) => {
        event.preventDefault();
        const newOwner = reownerInput.val() as string;
        const reownerVersions = reownerReownerVersions?.prop("checked") as boolean | undefined;
        const postEvents = reownerPostEvents?.prop("checked") as boolean | undefined;
        PostReowner.reowner(postId, newOwner, reownerVersions, postEvents);
        return false;
      });

      reownerDialog.open();

      const previousOwners = await previousOwnersPromise;

      reownerSelect.empty();
      previousOwners.forEach((owner: PreviousOwner) => {
        reownerSelect.append($("<option>").val(owner.id).text(`${owner.name} (${owner.id})`));
      });

      if (reownerSelect.data("allow-other")) {
        reownerSelect.append($("<option>").val(0).text("Other..."));
      }

      updateReownerInput(reownerSelect.val() as string | undefined);

      if (previousOwners.length > 0) {
        reownerStatus.text("");
        selectElement.style.display = "";
      } else {
        reownerStatus.text("No previous owners found.");
      }
    });
  }

  private static async previous_owners (post_id: string): Promise<PreviousOwner[]> {
    try {
      return await $.ajax({
        type: "GET",
        url: `/staff/post/posts/${post_id}/previous_owners.json`,
      });
    } catch (error: any) {
      const apiError = error as ApiResponseError;
      const errors = apiError?.responseJSON?.errors || [apiError?.responseJSON?.reason] || ["Unknown error"];
      const message = $.map(errors, (msg: string) => msg).join("; ");
      E621.Toast.alert("Error: " + message);
      return [];
    }
  }

  private static reowner (post_id: string, new_owner: string, reowner_versions: boolean = false, post_events: boolean = true): void {
    Post.notice_update("inc");
    let hasError = false;
    TaskQueue.add(async () => {
      try {
        await $.ajax({
          type: "POST",
          url: `/staff/post/posts/${post_id}/reowner.json`,
          data: {
            reowner: {
              new_owner: new_owner,
              reowner_versions: reowner_versions,
              post_events: post_events,
            },
          },
        });
        E621.Toast.notice("Reownered post.");
        location.reload();
      } catch (error: any) {
        const apiError = error as ApiResponseError;
        const errors = apiError?.responseJSON?.errors || [apiError?.responseJSON?.reason] || ["Unknown error"];
        const message = $.map(errors, (msg: string) => msg).join("; ");
        E621.Toast.alert("Error: " + message);
        hasError = true;
      } finally {
        if (!hasError) {
          Post.notice_update("dec");
        }
      }
    }, { name: "Post.reowner" });
  }
}
