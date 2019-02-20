import Utility from './utility'

let ModQueue = {};

ModQueue.processed = 0;

ModQueue.increment_processed = function() {
  if (Utility.meta("random-mode") === "1") {
    ModQueue.processed += 1;

    if (ModQueue.processed === 12) {
      window.location = Utility.meta("return-to");
    }
  }
}

$(function() {
  $(window).on("danbooru:modqueue_increment_processed", ModQueue.increment_processed);
});

export default ModQueue
