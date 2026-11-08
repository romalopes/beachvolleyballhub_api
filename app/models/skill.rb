class Skill < ApplicationRecord
  include Sluggable
  source_column :title

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :discipline
  has_many :drill_skills, dependent: :destroy
  has_many :drills, through: :drill_skills
  has_many :video_references, as: :referenced, dependent: :destroy
  has_many :videos, through: :video_references

  validates :title, presence: true

  VISIBILITY_LEVELS = %w[shared private unlisted].freeze
  STATUS_LEVELS = %w[draft published archived].freeze

  enum :visibility, { shared: "shared", private: "private", unlisted: "unlisted" }, prefix: true
  enum :status, { draft: "draft", published: "published", archived: "archived" }, prefix: true

  # Public catalogue: only published, shared skills are listed publicly.
  scope :published_and_shared, -> { where(status: :published, visibility: :shared) }

  def published_and_shared?
    status == "published" && visibility == "shared"
  end

  def to_param
    slug
  end
end
