module CommentsHelper
  def comment_vote_block(comment, vote)
    return if comment.is_sticky

    voted = !vote.nil?
    vote_score = voted ? vote.score : 0
    comment_score = comment.score

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
    else
      up_tag = down_tag = "".html_safe
    end
    score_tag = tag.li(comment.score, class: "comment-score #{score_class(comment_score)}", id: "comment-score-#{comment.id}")
    up_tag + score_tag + down_tag
  end
end
