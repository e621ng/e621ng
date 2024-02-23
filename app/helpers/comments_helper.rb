module CommentsHelper
  def comment_avatar(user)
    return "" if user.nil?
    post_id = user.avatar_id

    if post_id.nil?
      return tag.div(user.name[0], class: "comment-avatar-placeholder")
    end

    deferred_post_ids.add(post_id)
    tag.div(class: "post-thumb placeholder", id: "tp-#{post_id}", data: { id: post_id }) do
      tag.img(class: "thumb-img placeholder", src: "/images/thumb-preview.png", height: 100, width: 100)
    end
  end

  def comment_level_string(user)
    return "" if user.level <= 20
    tag.span(user.level_string, class: "comment-rank")
  end

  def comment_edited_notice(comment)
    if comment.was_warned?
      ""
    elsif comment.respond_to?(:updater) && comment.updater != comment.creator
      tag.span(safe_join(["Updated by ", link_to_user(comment.updater), " ", time_ago_in_words_tagged(comment.updated_at)]), class: "comment-edited-when")
    elsif comment.updated_at - comment.created_at > 5.minutes
      tag.span(safe_join(["Updated ", time_ago_in_words_tagged(comment.updated_at)]), class: "comment-edited-when")
    end
  end

  def comment_vote_block(comment, vote)
    return if comment.is_sticky

    voted = !vote.nil?
    vote_score = voted ? vote.score : 0
    comment_score = comment.score

    if CurrentUser.id == comment.creator_id
      up_tag = tag.li
    else
      up_tag = tag.li(
        tag.a(
          tag.i(class: "fas fa-arrow-up"),
          class: "comment-vote-link",
          href: (CurrentUser.is_member? ? nil : new_session_path),
          data: {
            comment: comment.id,
            action: 1,
          },
        ),
        id: "comment-vote-up-#{comment.id}",
      )
    end

    score_tag = tag.li(
      comment.score,
      id: "comment-score-#{comment.id}",
      class: "comment-score #{score_class(comment_score)}",
    )

    if CurrentUser.id == comment.creator_id
      down_tag = tag.li
    else
      down_tag = tag.li(
        tag.a(
          tag.i(class: "fas fa-arrow-down"),
          class: "comment-vote-link",
          href: (CurrentUser.is_member? ? nil : new_session_path),
          data: {
            comment: comment.id,
            action: -1,
          },
        ),
        id: "comment-vote-down-#{comment.id}",
      )
    end

    tag.div(
      up_tag + score_tag + down_tag,
      class: "comment-vote",
      data: {
        id: comment.id,
        vote: score_class(vote_score)[6..],
        score: comment_score,
      },
    )
  end
end
