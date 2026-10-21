# Builds and persists a TrainingSeries from a template plus recurrence input,
# then generates its occurrences atomically.
#
# The series stores a full defaults snapshot at creation. Later template edits
# therefore cannot rewrite what the coach previewed, and occurrences keep their
# own values even if the template changes.
class TrainingSeriesCreator
  OVERRIDABLE_DEFAULTS = %i[
    title description organisation_id group_id coach_profile_id location
    location_detail level capacity visibility
  ].freeze

  Result = Struct.new(:series, :generator_result, :errors, keyword_init: true) do
    def success?
      errors.empty? && series.present?
    end
  end

  # Used by both creation and preview so the dates the coach sees are built from
  # exactly the same object that will be saved.
  def self.build_series(template:, attributes:, actor: nil)
    new(template: template, attributes: attributes, actor: actor).build_series
  end

  def self.call(template:, attributes:, actor: nil)
    new(template: template, attributes: attributes, actor: actor).call
  end

  def initialize(template:, attributes:, actor: nil)
    @template = template
    @attributes = attributes
    @actor = actor
    @errors = []
  end

  def call
    series = build_series
    unless series.valid?
      return Result.new(series: nil, generator_result: nil,
                        errors: series.errors.full_messages)
    end

    generator_result = nil
    ActiveRecord::Base.transaction do
      series.save!
      generator_result = TrainingSeriesGenerator.new(series).call
      unless generator_result.success?
        @errors = generator_result.errors
        raise ActiveRecord::Rollback
      end
    end

    if @errors.any?
      Result.new(series: nil, generator_result: nil, errors: @errors)
    else
      Result.new(series: series, generator_result: generator_result, errors: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(series: nil, generator_result: nil,
               errors: e.record.errors.full_messages.presence || [ e.message ])
  end

  def build_series
    TrainingSeries.new(
      training_template: template,
      organisation_id: series_organisation_id,
      created_by: actor,
      frequency: attributes[:frequency].presence || "weekly",
      interval: attributes[:interval].presence || 1,
      weekdays: attributes[:weekdays],
      starts_on: attributes[:starts_on],
      ends_on: attributes[:ends_on],
      local_start_time: attributes[:local_start_time],
      duration_minutes: attributes[:duration_minutes].presence || template.duration_minutes,
      # The application default zone is UTC; a series must always carry an
      # explicit IANA zone rather than silently inheriting the server's.
      time_zone: attributes[:time_zone].presence || Time.zone.name,
      status: "active",
      defaults_snapshot: defaults_snapshot
    )
  end

  private

  attr_reader :template, :attributes, :actor

  def series_organisation_id
    attributes[:organisation_id].presence ||
      overrides[:organisation_id].presence ||
      template.organisation_id
  end

  def defaults_snapshot
    template.defaults_for_series.merge(overrides.slice(*OVERRIDABLE_DEFAULTS))
  end

  # Accepts ActionController::Parameters or a plain hash; unknown keys are
  # dropped so a typo cannot silently become a stored default.
  def overrides
    raw = attributes[:overrides] || attributes[:defaults] || {}
    raw = raw.to_h if raw.respond_to?(:to_h)
    raw = raw.to_h.symbolize_keys
    raw.slice(*OVERRIDABLE_DEFAULTS)
  end
end
