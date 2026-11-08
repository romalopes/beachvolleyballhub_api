module Admin
  class DashboardController < ApplicationController
    before_action :authorize_admin!

    def index
      @skills_count = Skill.count
      @disciplines_count = Discipline.count
      @drills_count = Drill.count
    end
  end
end
