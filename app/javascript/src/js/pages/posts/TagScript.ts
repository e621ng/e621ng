export class TagScriptError extends Error {
  constructor (message: string) {
    super(message);
    this.name = "TagScriptError";
  }
}

export interface TagScriptCommand {
  /** Tag changes emitted when the condition holds */
  tags: string[];
  /** Lowercased predicate; absent for unconditional commands */
  when?: { require: string[]; exclude: string[] };
}

// An unterminated bracket swallows the rest of the script, so it fails as one bad command
const TOKENIZE = /\[[^\]]*\]?|\S+/g;
const CONDITIONAL = /^\[if\s+([^,\]\s][^,\]]*?)\s*,\s*([^,\]\s][^,\]]*?)\s*\]$/i;
const RESET = /^\[reset\]$/i;

/**
 * Evaluates tag scripts: space-separated tag changes (`tag`, `-tag`), plus
 * `[if PRED, CONSEQ]` conditionals checked against a post's current tags.
 * `[reset]` is accepted for compatibility with old scripts and does nothing.
 */
export default class TagScript {

  /** @throws {TagScriptError} on malformed or unknown bracket commands */
  static parse (script: string): TagScriptCommand[] {
    const commands: TagScriptCommand[] = [];

    for (const token of script.match(TOKENIZE) ?? []) {
      if (!token.startsWith("[")) {
        commands.push({ tags: [token] });
        continue;
      }
      if (RESET.test(token)) continue;

      const match = token.match(CONDITIONAL);
      if (!match) throw new TagScriptError(`Invalid tag script command: ${token}`);

      const require: string[] = [], exclude: string[] = [];
      for (const tag of match[1].toLowerCase().split(/\s+/)) {
        if (tag.startsWith("-")) {
          if (tag.length > 1) exclude.push(tag.slice(1));
        } else require.push(tag);
      }
      commands.push({ tags: match[2].split(/\s+/), when: { require, exclude } });
    }

    return commands;
  }

  static evaluate (commands: TagScriptCommand[], tags: ReadonlySet<string>): string[] {
    return commands.flatMap((command) => {
      const when = command.when;
      if (!when) return command.tags;
      const matches = when.require.every((tag) => tags.has(tag)) && !when.exclude.some((tag) => tags.has(tag));
      return matches ? command.tags : [];
    });
  }

  static hasConditionals (commands: TagScriptCommand[]): boolean {
    return commands.some((command) => command.when !== undefined);
  }
}
