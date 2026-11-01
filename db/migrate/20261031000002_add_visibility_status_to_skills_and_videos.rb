# Adds the visibility/publication lifecycle to the remaining catalogue/media
# resources that carried a creator but had no way to hide or draft a record.
#
# Defaults are chosen so existing behaviour is preserved: catalogue and media
# content is public by default (`published` + `shared`). Unlike drills (authored
# content that starts as `draft` for review), a skill or video is usable the
# moment it is created, but it can now be made `private`/`unlisted` or moved to
# `draft`/`archived`.
class AddVisibilityStatusToSkillsAndVideos < ActiveRecord::Migration[8.1]
  def change
    %i[skills videos].each do |table|
      add_column table, :visibility, :string, null: false, default: "shared"
      add_column table, :status, :string, null: false, default: "published"
      add_column table, :published_at, :datetime
      add_index table, :visibility
      add_index table, :status
    end
  end
end
