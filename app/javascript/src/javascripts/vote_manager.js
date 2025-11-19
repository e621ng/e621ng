import Page from "./utility/page";
import Utility from "./utility";

class VoteManager {
  constructor (itemType) {
    this._type = itemType;
    this.displayType = itemType.charAt(0).toUpperCase() + itemType.slice(1);
    this.allSelected = false;
    this.init();
  }

  init () {
    const self = this;
    self.lastSelected = 0;
    $("#votes").on("click", "tbody tr", function (evt) {
      if ($(evt.target).is("a")) return;
      evt.preventDefault();
      if (evt.shiftKey) {
        self.toggleRowsBetween([self.lastSelected, this.rowIndex]);
      }
      $(this).toggleClass("selected");
      self.lastSelected = this.rowIndex;
    });
    $("#select-all-votes").on("click", () => self.selectAll());
    $("#lock-votes").on("click", () => self.lockVotes());
    $("#delete-votes").on("click", () => self.deleteVotes());
  }

  selectAll () {
    this.allSelected = !this.allSelected;
    if (this.allSelected)
      $("#votes").find("tr").addClass("selected");
    else
      $("#votes").find("tr").removeClass("selected");
  }

  toggleRowsBetween (indices) {
    this.lastSelected = indices[1];
    let rows = $("#votes").find("tr");
    indices = indices.sort();
    rows = rows.slice(indices[0], indices[1]);
    rows.toggleClass("selected");
  }

  selectedVotes () {
    return $("#votes>tbody>tr.selected").map(function () {
      return $(this).attr("id").substring(1);
    }).get();
  }

  lockVotes () {
    const votes = this.selectedVotes();
    if (!votes.length) return;
    if (!confirm(`Are you sure that you want to lock ${votes.length} votes?`)) return;

    $.ajax({
      url: `/${this._type}_votes/lock.json`,
      method: "post",
      data: {
        ids: votes.join(","),
      },
    }).done(() => {
      Utility.notice(`${this.displayType} votes locked.`);
    });
  }

  deleteVotes () {
    const votes = this.selectedVotes();
    if (!votes.length) return;
    if (!confirm(`Are you sure that you want to delete ${votes.length} votes?`)) return;

    $.ajax({
      url: `/${this._type}_votes/delete.json`,
      method: "post",
      data: {
        ids: votes.join(","),
      },
    }).done(() => {
      Utility.notice(`${this.displayType} votes deleted.`);
    });
  }
}

export default VoteManager;

$(() => {
  if (Page.matches("post-votes")) new VoteManager("post");
  else if (Page.matches("comment-votes")) new VoteManager("comment");
});
