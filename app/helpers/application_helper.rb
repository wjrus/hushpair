module ApplicationHelper
  def build_label
    release = ENV["HUSHPAIR_RELEASE"].presence || ENV["RENDER_GIT_COMMIT"].presence || ENV["GIT_COMMIT_SHA"].presence
    release ||= local_git_revision
    return unless release.present?

    "build #{release.to_s.first(12)}"
  end

  private

  def local_git_revision
    @local_git_revision ||= begin
      revision = `git rev-parse --short=12 HEAD 2>/dev/null`.strip
      revision if $?.success? && revision.present?
    end
  end
end
