class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    @categories = Category.all
    @skills = Skill.all
    # Public home page: only published, shared drills.
    @drills = Drill.published_and_shared
  end
end
