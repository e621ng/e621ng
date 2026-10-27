import Logger from "@/utility/Logger";
import { TaskCancelled } from "@/utility/TaskQueue";
import Favorite from "./Favorite";
import PostVote, { PostVoteResponse } from "./PostVote";

let _data: Record<string, any> = {},
  loaded = false;
const _get = function () {
  if (loaded) return _data;
  try {
    const el = document.getElementById("post-data");
    if (!el) {
      // Can't find the element - likely on the posts#index page
      return {};
    }

    const bytes = Uint8Array.from(atob(el.textContent), (c) => c.charCodeAt(0));
    const json = new TextDecoder().decode(bytes);
    _data = JSON.parse(json);
    loaded = true;
    return _data;
  } catch (e) {
    _data = {};
    loaded = true;
    console.error("Failed to load post data:", e);
    return {};
  }
};

class CurrentPost {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: CurrentPost | null = null;
  public static get instance (): CurrentPost {
    if (!CurrentPost._instance)
      CurrentPost._instance = new CurrentPost();
    return CurrentPost._instance;
  }

  private static Logger = new Logger("CurrentPost");


  /* ============================== */
  /* ===== Instance properties ==== */
  /* ============================== */

  // Properties from the PostBlueprint payload
  public readonly id: number;
  public readonly created_at: string;
  public readonly updated_at: string;
  public readonly change_seq: number;

  public readonly files: CurrentPostFiles;

  public readonly uploader_id: number;
  public readonly uploader_name: string;
  public readonly approver_id: number;

  public readonly stats: CurrentPostStats;
  public readonly flags: CurrentPostFlags;
  public readonly has: CurrentPostHas;
  public readonly relationships: CurrentPostRelationships;

  public readonly pools: number[];
  public readonly rating: string;
  public readonly locked_tags: string[];
  public readonly sources: string[];
  public readonly description: string;

  public readonly tags: CurrentPostTags;

  // Additional properties
  public readonly initial_size: string;

  // Derived properties
  public readonly is: CurrentPostIs;

  private constructor () {
    if (CurrentPost._instance)
      throw new Error("CurrentPost is a singleton class. Use CurrentPost.instance to access the instance.");

    const obj = _get() || {};
    if (!Object.keys(obj).length)
      throw new Error("No embedded post data found.");

    if (!obj["id"] || typeof obj["id"] !== "number")
      CurrentPost.Logger.error("Malformed post data.");

    // Properties from the PostBlueprint payload
    this.id = obj["id"] || 0;
    this.created_at = obj["created_at"] || "";
    this.updated_at = obj["updated_at"] || "";
    this.change_seq = obj["change_seq"] || 0;

    this.files = obj["files"] || {} as CurrentPostFiles;

    this.uploader_id = obj["uploader_id"] || 0;
    this.uploader_name = obj["uploader_name"] || "";
    this.approver_id = obj["approver_id"] || 0;

    this.stats = obj["stats"] || {} as CurrentPostStats;
    if (!this.stats.score) this.stats.score = { up: 0, down: 0, total: 0 };
    this.flags = obj["flags"] || {} as CurrentPostFlags;
    this.has = obj["has"] || {} as CurrentPostHas;
    this.relationships = obj["relationships"] || {} as CurrentPostRelationships;

    this.pools = obj["pools"] || [];
    this.rating = obj["rating"] || "";
    this.locked_tags = obj["locked_tags"] || [];
    this.sources = obj["sources"] || [];
    this.description = obj["description"] || "";

    this.tags = obj["tags"] || {};

    // Additional properties
    this.initial_size = obj["initial_size"] || "";

    // Derived properties
    this.is = {
      flash: this.files?.meta?.ext === "swf",
      video: ["webm", "mp4"].includes(this.files?.meta?.ext),
      image: !["swf", "webm", "mp4"].includes(this.files?.meta?.ext),
      visible: !!this.files?.original?.url,
    };

    CurrentPost.Logger.log(`Loaded: ${this.id}`);
  }


  /* ============================== */
  /* ===== Getters / Setters ====== */
  /* ============================== */

  public get exists (): boolean {
    return typeof this.id === "number" && this.id > 0;
  }

  /** Sign of the total score, matching the `post_score_state` helper. */
  public get scoreState (): -1 | 0 | 1 {
    const total = this.stats?.score?.total || 0;
    return total > 0 ? 1 : (total < 0 ? -1 : 0);
  }

  public get favorited (): boolean {
    return !!this.stats?.is_favorited;
  }


  /* ============================== */
  /* ======== Public API ========== */
  /* ============================== */

  /**
   * Casts a vote on the current post.
   * Emits `post:vote:start`, then `post:vote` on success, then `post:vote:end`.
   * A request superseded by a newer one (TaskCancelled) emits no `end`: the newer request owns the lifecycle.
   * @param vote 1 for an upvote, -1 for a downvote.
   * @param prevent_unvote If true, voting the same direction again does not remove the vote.
   */
  public vote (vote: number, prevent_unvote: boolean = false): Promise<PostVoteResponse> {
    if (!this.exists)
      return Promise.reject(new Error("No current post available for voting."));

    const lifecycle: PostVoteEvent = { post_id: this.id, direction: vote };
    $(document).trigger("post:vote:start", lifecycle);

    return PostVote.vote(this.id, vote, prevent_unvote).then(
      (data) => {
        this.stats.score.total = data.score;
        this.stats.score.up = data.up;
        this.stats.score.down = data.down;
        this.stats.vote = data.our_score;

        $(document).trigger("post:vote", { post_id: this.id, stats: this.stats } satisfies PostStatsEvent);
        $(document).trigger("post:vote:end", lifecycle);
        return data;
      },
      (error) => {
        if (!(error instanceof TaskCancelled))
          $(document).trigger("post:vote:end", lifecycle);
        throw error;
      },
    );
  }

  public voteUp (): Promise<PostVoteResponse> {
    return this.vote(1, true);
  }

  public voteDown (): Promise<PostVoteResponse> {
    return this.vote(-1, true);
  }

  /**
   * Favorites the current post.
   * Emits `post:favorite:start`, then `post:favorite` on success, then `post:favorite:end`.
   * Same TaskCancelled rule as `vote()`.
   */
  public favorite (delay: number = 500): Promise<FavoriteResponse | void> {
    if (!this.exists)
      return Promise.reject(new Error("No current post available for favoriting."));

    const lifecycle: PostFavoriteEvent = { post_id: this.id, favorited: true };
    $(document).trigger("post:favorite:start", lifecycle);

    return Favorite.create(this.id, delay).then(
      (data) => {
        this.stats.is_favorited = true;
        if (typeof data?.favorite_count === "number") this.stats.fav_count = data.favorite_count;

        $(document).trigger("post:favorite", { post_id: this.id, stats: this.stats } satisfies PostStatsEvent);
        $(document).trigger("post:favorite:end", lifecycle);
        return data;
      },
      (error: Error & { cause?: unknown }) => {
        // The server state is what we wanted, so just sync the model
        if (error?.cause === "You have already favorited this post") {
          this.stats.is_favorited = true;
          $(document).trigger("post:favorite", { post_id: this.id, stats: this.stats } satisfies PostStatsEvent);
          $(document).trigger("post:favorite:end", lifecycle);
          return;
        }

        if (!(error instanceof TaskCancelled))
          $(document).trigger("post:favorite:end", lifecycle);
        throw error;
      },
    );
  }

  /** Removes the current post from favorites. Emits the same events as `favorite()`. */
  public unfavorite (delay: number = 500): Promise<FavoriteResponse> {
    if (!this.exists)
      return Promise.reject(new Error("No current post available for unfavoriting."));

    const lifecycle: PostFavoriteEvent = { post_id: this.id, favorited: false };
    $(document).trigger("post:favorite:start", lifecycle);

    return Favorite.destroy(this.id, delay).then(
      (data) => {
        this.stats.is_favorited = false;
        if (typeof data?.favorite_count === "number") this.stats.fav_count = data.favorite_count;

        $(document).trigger("post:favorite", { post_id: this.id, stats: this.stats } satisfies PostStatsEvent);
        $(document).trigger("post:favorite:end", lifecycle);
        return data;
      },
      (error) => {
        if (!(error instanceof TaskCancelled))
          $(document).trigger("post:favorite:end", lifecycle);
        throw error;
      },
    );
  }
}

export default CurrentPost.instance;

/** Payload of `post:vote:start` and `post:vote:end`. */
export interface PostVoteEvent {
  post_id: number,
  direction: number,
}

/** Payload of `post:favorite:start` and `post:favorite:end`. `favorited` is the requested state. */
export interface PostFavoriteEvent {
  post_id: number,
  favorited: boolean,
}

/** Payload of `post:vote` and `post:favorite`. `stats` is the live CurrentPost.stats object. */
export interface PostStatsEvent {
  post_id: number,
  stats: CurrentPostStats,
}

/** Response of favorites#create / favorites#destroy. */
export interface FavoriteResponse {
  post_id: number,
  favorite_count: number,
}

interface CurrentPostFiles {
  meta: {
    md5: string,
    ext: string,
    size: number,
    duration: number | null,
    has_sample: boolean,
  },

  original: {
    width: number,
    height: number,
    url?: string | null,
  },

  preview: {
    width: number,
    height: number,
    jpg?: string | null,
    webp?: string | null,
  },

  sample: {
    width: number,
    height: number,
    jpg?: string | null,
    webp?: string | null,
  },

  video: {
    has: boolean,
    original: {
      codec: string,
      fps: number,
      size: number,
      width: number,
      height: number,
      url?: string | null,
    },
    variants: Record<string, VideoSample>,
    samples: Record<string, VideoSample>,
  }
}

interface VideoSample {
  width: number,
  height: number,
  codec: string,
  fps: number,
  size: number,
  url?: string | null,
}

export interface CurrentPostStats {
  score: {
    up: number,
    down: number,
    total: number,
  },
  fav_count: number,
  is_favorited: boolean,
  vote: number,
  comment_count: number,
  hotness: number,
}

interface CurrentPostFlags {
  pending: boolean,
  flagged: boolean,
  note_locked: boolean,
  status_locked: boolean,
  rating_locked: boolean,
  deleted: boolean,
}

interface CurrentPostHas {
  parent: boolean,
  children: boolean,
  active_children: boolean,
  notes: boolean,
  sample: boolean,
}

interface CurrentPostIs {
  flash: boolean,
  video: boolean,
  image: boolean,
  visible: boolean,
}

interface CurrentPostRelationships {
  parent_id: number | null,
  children: number[],
}

type TagCategory = "general" | "artist" | "contributor" | "copyright" | "character" | "species" | "invalid" | "meta" | "lore";

type CurrentPostTags = Record<TagCategory, string[]>;
