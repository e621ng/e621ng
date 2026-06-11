import Constants from "@/components/autocomplete/Constants";
import * as Types from "@/components/autocomplete/Types";
import findPools from "./Pools";
import findTags from "./Tags";
import findUsers from "./Users";
import { Utils } from "./index";

function getStaticMetatags (metatag: string, term: string): Types.StaticMetatagItem[] {
  const options = Constants.STATIC_METATAGS[metatag];
  if (!options) return [];
  term = term.trim().toLowerCase();

  return (options as string[])
    .filter(option => !term || option.startsWith(term))
    .map(option => ({
      name: `${metatag}:${option}`,
      label: `${metatag}:${option}`,
      category: "metatag" as const,
      type: "metatag" as const,
    }))
    .sort((a, b) => a.name.localeCompare(b.name))
    .slice(0, 10);
};

const getMetatags = async (metatag: string, term: string): Promise<Types.MetatagItem[]> => {
  if (Constants.STATIC_METATAGS[metatag])
    return getStaticMetatags(metatag, term);

  switch (metatag) {
    case "user":
    case "approver":
    case "commenter":
    case "comm":
    case "noter":
    case "noteupdater":
    case "fav":
    case "favoritedby":
    case "flagger":
    case "flaggedby":
    case "deleter":
    case "deletedby":
    case "upvote":
    case "downvote":
      return Utils.searchItems<Types.UserItem>(term, findUsers).then(results => results.map(user => ({
        ...user,
        name: `${metatag}:${user.name}`,
      })));
    case "pool":
      return Utils.searchItems<Types.PoolItem>(term, findPools).then(results => results.map(pool => ({
        ...pool,
        name: `${metatag}:${pool.name}`,
      })));
    default:
      if (Constants.TAG_CATEGORIES.includes(metatag)) {
        // Autocomplete does not support searching by category.
        // Additionally, the backend does not match tags on posts with category prefix, so the result is empty.
        // For that reason, we skip adding the category prefix here.
        return Utils.searchItems<Types.TagItem>(term, findTags);
      }
      return [];
  }
};

export default getMetatags;
