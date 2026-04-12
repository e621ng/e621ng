/* eslint-disable comma-dangle */
const TagScript = {
  parse (script) {
    return script.match(/\[.+?\]|\S+/g);
  },
  test (tags, predicate) {
    const split_pred = predicate.match(/\S+/g);

    for (const x of split_pred) {
      if (x[0] === "-") {
        if (tags.has(x.substr(1))) {
          return false;
        }
      } else if (!tags.has(x)) {
        return false;
      }
    }

    return true;
  },
  process (tags, command) {
    if (command.match(/^\[if/)) {
      const match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/);
      if (TagScript.test(tags, match[1])) {
        return TagScript.process(tags, match[2]);
      } else {
        return null;
      }
    } else if (command === "[reset]") {
      return null;
    } else {
      return command;
    }
  },
  run (tags, tag_script) {
    const changes = [];
    const commands = TagScript.parse(tag_script);

    for (const command of commands) {
      const result = TagScript.process(tags, command);
      if (result !== null) {
        changes.push(result);
      }
    }
    return changes.join(" ");
  }
};

export default TagScript;
