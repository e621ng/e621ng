module CommentsHelper
  def comment_vote_block(comment, vote)
    voted = !vote.nil?
    vote_score = voted ? vote.score : 0
    comment_score = comment.score

    def score_class(score)
      return 'score-neutral' if score == 0
      score > 0 ? 'score-positive' : 'score-negative'
    end

    def confirm_score_class(score, want)
      return 'score-neutral' if score != want || score == 0
      score_class(score)
    end

    up_tag = tag.li(tag.a('&#x25B2;'.html_safe, class: 'comment-vote-up-link', 'data-id': comment.id),
                    class: confirm_score_class(vote_score, 1),
                    id: "comment-vote-up-#{comment.id}")
    down_tag = tag.li(tag.a('&#x25BC;'.html_safe, class: 'comment-vote-down-link', 'data-id': comment.id),
                      class: confirm_score_class(vote_score, -1),
                      id: "comment-vote-down-#{comment.id}")
    score_tag = tag.li(comment.score, class: "comment-score #{score_class(comment_score)}", id: "comment-score-#{comment.id}")
    up_tag + score_tag + down_tag
  end
end