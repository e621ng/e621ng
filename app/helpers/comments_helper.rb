# frozen_string_literal: true

module CommentsHelper
  def comment_vote_block(comment)
    return if comment.is_sticky

    vote_score = comment.vote_by
    score_tag = tag.li(comment.score, class: "comment-score #{score_class(comment.score)}", id: "comment-score-#{comment.id}")

    if CurrentUser.is_member?
      up_tag = tag.li(
        tag.a("▲", class: "comment-vote-up-link", data: { id: comment.id }),
        class: confirm_score_class(vote_score, 1, false),
        id: "comment-vote-up-#{comment.id}",
      )
      down_tag = tag.li(
        tag.a("▼", class: "comment-vote-down-link", data: { id: comment.id }),
        class: confirm_score_class(vote_score, -1, false),
        id: "comment-vote-down-#{comment.id}",
      )
      up_tag + score_tag + down_tag
    else
      score_tag
    end
  end
end
