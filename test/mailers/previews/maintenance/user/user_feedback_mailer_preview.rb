# frozen_string_literal: true

class Maintenance::User::UserFeedbackMailerPreview < ActionMailer::Preview # rubocop:disable Style/ClassAndModuleChildren
  def feedback_notice
    feedback = UserFeedback.new(user: User.first, creator: User.system, category: "negative", body: %(Don't be a troll. "[Source]":/comments/9690824

[section=Disruptive Behavior]
e621 is an open and friendly community that people visit to share and enjoy furry artwork.
People can have different opinions, but that does not give them permission to make someone else feel uncomfortable or unwanted.

* Do not make messages with the apparent purpose of upsetting someone. That includes picking fights, baiting arguments, calling names, or making remarks regarding personal grievances, quarrels, or malicious rumors.
* Do not purposefully or repeatedly spread false or defamatory information.
* Do not mention any actions of suicide, self harm / mutilation, depression-induced pain, or other malicious acts directed towards the self.
* Do not encourage others to engage in harmful behaviors, including suicide, eating disorders, or other forms of self harm.
* Do not give others medical or legal advice that could result in harm coming to themselves or others.
* Do not promote ideologies that are harmful to public safety.
* Do not brag about saving DNP or pirated material, and do not encourage others to do so.
* Do not maliciously impersonate any individuals or organizations.
* Do not demand that certain administrative actions be taken against another user. Do not claim personal influence over staff decisions.
* Do not disobey any direct instructions made by staff members.

"[Code of Conduct - Disruptive Behavior]":/wiki_pages/e621:rules#disruptive
[/section]
))
    user = feedback.user
    Maintenance::User::UserFeedbackMailer.feedback_notice(user, feedback)
  end
end
