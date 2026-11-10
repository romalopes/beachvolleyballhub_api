# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_10_191000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "account_addresses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "street_address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_addresses_on_account_id", unique: true
  end

  create_table "account_invitations", force: :cascade do |t|
    t.bigint "invited_by_id", null: false
    t.string "token_digest", null: false
    t.string "invitee_email"
    t.string "status", default: "active", null: false
    t.datetime "expires_at", null: false
    t.datetime "emailed_at"
    t.datetime "used_at"
    t.datetime "revoked_at"
    t.datetime "declined_at"
    t.bigint "used_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_account_invitations_on_expires_at"
    t.index ["invited_by_id"], name: "index_account_invitations_on_invited_by_id"
    t.index ["status"], name: "index_account_invitations_on_status"
    t.index ["token_digest"], name: "index_account_invitations_on_token_digest", unique: true
    t.index ["used_by_id"], name: "index_account_invitations_on_used_by_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_accounts_on_user_id", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_activities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "entity_type", null: false
    t.bigint "entity_id", null: false
    t.string "entity_label"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_admin_activities_on_action_and_created_at"
    t.index ["entity_type", "entity_id"], name: "index_admin_activities_on_entity_type_and_entity_id"
    t.index ["user_id"], name: "index_admin_activities_on_user_id"
  end

  create_table "analyses", force: :cascade do |t|
    t.string "title", null: false
    t.text "summary"
    t.string "status", default: "draft", null: false
    t.bigint "created_by_id", null: false
    t.bigint "assigned_coach_profile_id"
    t.bigint "organisation_id"
    t.bigint "group_id"
    t.bigint "training_session_id"
    t.bigint "tournament_id"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_coach_profile_id"], name: "index_analyses_on_assigned_coach_profile_id"
    t.index ["created_by_id"], name: "index_analyses_on_created_by_id"
    t.index ["group_id"], name: "index_analyses_on_group_id"
    t.index ["organisation_id"], name: "index_analyses_on_organisation_id"
    t.index ["status", "updated_at"], name: "index_analyses_on_status_and_updated_at"
    t.index ["tournament_id"], name: "index_analyses_on_tournament_id"
    t.index ["training_session_id"], name: "index_analyses_on_training_session_id"
    t.check_constraint "status::text <> 'archived'::text OR archived_at IS NOT NULL", name: "analyses_archived_at"
    t.check_constraint "status::text <> 'published'::text OR published_at IS NOT NULL", name: "analyses_published_at"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'archived'::character varying::text])", name: "analyses_status"
  end

  create_table "analysis_annotations", force: :cascade do |t|
    t.bigint "analysis_video_id", null: false
    t.bigint "author_id", null: false
    t.bigint "player_profile_id"
    t.integer "timestamp_seconds", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_video_id", "timestamp_seconds"], name: "idx_on_analysis_video_id_timestamp_seconds_1522cf9aaa"
    t.index ["analysis_video_id"], name: "index_analysis_annotations_on_analysis_video_id"
    t.index ["author_id"], name: "index_analysis_annotations_on_author_id"
    t.index ["player_profile_id"], name: "index_analysis_annotations_on_player_profile_id"
    t.check_constraint "timestamp_seconds >= 0", name: "analysis_annotations_timestamp"
  end

  create_table "analysis_assessment_sessions", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "assessment_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_id", "assessment_session_id"], name: "index_analysis_assessment_sessions_unique", unique: true
    t.index ["analysis_id"], name: "index_analysis_assessment_sessions_on_analysis_id"
    t.index ["assessment_session_id"], name: "index_analysis_assessment_sessions_on_assessment_session_id"
  end

  create_table "analysis_comments", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "author_id", null: false
    t.bigint "parent_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_id", "created_at"], name: "index_analysis_comments_on_analysis_id_and_created_at"
    t.index ["analysis_id"], name: "index_analysis_comments_on_analysis_id"
    t.index ["author_id"], name: "index_analysis_comments_on_author_id"
    t.index ["parent_id"], name: "index_analysis_comments_on_parent_id"
  end

  create_table "analysis_participants", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "player_profile_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_id", "player_profile_id"], name: "index_analysis_participants_unique", unique: true
    t.index ["analysis_id"], name: "index_analysis_participants_on_analysis_id"
    t.index ["player_profile_id"], name: "index_analysis_participants_on_player_profile_id"
  end

  create_table "analysis_videos", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "video_id"
    t.string "source_type", null: false
    t.string "title"
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_id", "position"], name: "index_analysis_videos_on_analysis_id_and_position"
    t.index ["analysis_id"], name: "index_analysis_videos_on_analysis_id"
    t.index ["video_id"], name: "index_analysis_videos_on_video_id"
    t.check_constraint "source_type::text = 'external'::text AND video_id IS NOT NULL OR source_type::text = 'upload'::text AND video_id IS NULL", name: "analysis_videos_source"
    t.check_constraint "source_type::text = ANY (ARRAY['external'::character varying::text, 'upload'::character varying::text])", name: "analysis_videos_source_type"
  end

  create_table "api_idempotency_keys", force: :cascade do |t|
    t.string "actor_scope", null: false
    t.string "request_key", null: false
    t.string "request_method", null: false
    t.string "request_path", null: false
    t.string "request_digest", null: false
    t.integer "status", null: false
    t.string "content_type", default: "application/json", null: false
    t.text "response_body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_scope", "request_key"], name: "index_api_idempotency_keys_on_actor_and_key", unique: true
    t.index ["created_at"], name: "index_api_idempotency_keys_on_created_at"
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "assessment_categories", force: :cascade do |t|
    t.bigint "assessment_definition_id", null: false
    t.bigint "discipline_id"
    t.bigint "discipline_custom_id"
    t.integer "weight", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_definition_id", "discipline_custom_id"], name: "index_assessment_categories_on_definition_and_discipline_custom", unique: true, where: "(discipline_custom_id IS NOT NULL)"
    t.index ["assessment_definition_id", "discipline_id"], name: "index_assessment_categories_on_definition_and_discipline", unique: true, where: "(discipline_id IS NOT NULL)"
    t.index ["assessment_definition_id"], name: "index_assessment_categories_on_assessment_definition_id"
    t.index ["discipline_custom_id"], name: "index_assessment_categories_on_discipline_custom_id"
    t.index ["discipline_id"], name: "index_assessment_categories_on_discipline_id"
    t.check_constraint "\"position\" >= 0", name: "assessment_categories_position_non_negative"
    t.check_constraint "discipline_id IS NOT NULL AND discipline_custom_id IS NULL OR discipline_id IS NULL AND discipline_custom_id IS NOT NULL", name: "assessment_categories_source_xor"
    t.check_constraint "weight > 0", name: "assessment_categories_weight_positive"
  end

  create_table "assessment_category_scores", force: :cascade do |t|
    t.bigint "assessment_id", null: false
    t.bigint "assessment_category_id", null: false
    t.integer "score"
    t.integer "reported_value"
    t.string "scale", default: "one_to_ten", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "criterion_id"
    t.index ["assessment_category_id"], name: "index_assessment_category_scores_on_assessment_category_id"
    t.index ["assessment_id", "assessment_category_id", "criterion_id"], name: "index_assessment_category_scores_on_category_and_criterion", unique: true, where: "(criterion_id IS NOT NULL)"
    t.index ["assessment_id", "assessment_category_id"], name: "index_assessment_category_scores_on_assessment_and_category", unique: true, where: "(criterion_id IS NULL)"
    t.index ["assessment_id"], name: "index_assessment_category_scores_on_assessment_id"
    t.index ["criterion_id"], name: "index_assessment_category_scores_on_criterion_id"
    t.check_constraint "(score IS NULL) = (reported_value IS NULL)", name: "assessment_category_scores_score_pair"
    t.check_constraint "scale::text = ANY (ARRAY['one_to_five'::character varying::text, 'one_to_ten'::character varying::text, 'one_to_hundred'::character varying::text])", name: "assessment_category_scores_scale"
    t.check_constraint "score IS NULL OR score >= 0 AND score <= 100", name: "assessment_category_scores_score_range"
  end

  create_table "assessment_definitions", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "draft", null: false
    t.text "description"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_assessment_definitions_on_created_by_id"
    t.index ["name"], name: "index_assessment_definitions_on_name"
    t.index ["status"], name: "index_assessment_definitions_on_status"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'archived'::character varying::text])", name: "assessment_definitions_status"
  end

  create_table "assessment_session_participants", force: :cascade do |t|
    t.bigint "assessment_session_id", null: false
    t.bigint "player_profile_id", null: false
    t.string "inclusion", default: "included", null: false
    t.string "missing_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_session_id", "player_profile_id"], name: "index_session_participants_on_session_and_player", unique: true
    t.index ["assessment_session_id"], name: "index_assessment_session_participants_on_assessment_session_id"
    t.index ["player_profile_id"], name: "index_assessment_session_participants_on_player_profile_id"
    t.check_constraint "inclusion::text = ANY (ARRAY['included'::character varying::text, 'excluded'::character varying::text])", name: "assessment_session_participants_inclusion"
  end

  create_table "assessment_sessions", force: :cascade do |t|
    t.bigint "assessment_definition_id", null: false
    t.bigint "coach_profile_id", null: false
    t.bigint "created_by_id"
    t.bigint "group_id"
    t.string "name"
    t.date "scheduled_on"
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_definition_id"], name: "index_assessment_sessions_on_assessment_definition_id"
    t.index ["coach_profile_id"], name: "index_assessment_sessions_on_coach_profile_id"
    t.index ["created_by_id"], name: "index_assessment_sessions_on_created_by_id"
    t.index ["group_id"], name: "index_assessment_sessions_on_group_id"
    t.index ["scheduled_on"], name: "index_assessment_sessions_on_scheduled_on"
    t.index ["status"], name: "index_assessment_sessions_on_status"
    t.check_constraint "status::text <> 'published'::text OR published_at IS NOT NULL", name: "assessment_sessions_published_requires_timestamp"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'withdrawn'::character varying::text])", name: "assessment_sessions_status"
  end

  create_table "assessments", force: :cascade do |t|
    t.bigint "player_profile_id", null: false
    t.bigint "coach_profile_id", null: false
    t.bigint "created_by_id"
    t.bigint "training_session_id"
    t.integer "score"
    t.integer "reported_value"
    t.string "scale", default: "one_to_ten"
    t.text "notes"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "discipline_id"
    t.string "custom_discipline"
    t.bigint "assessment_definition_id"
    t.bigint "assessment_session_id"
    t.index ["assessment_definition_id"], name: "index_assessments_on_assessment_definition_id"
    t.index ["assessment_session_id"], name: "index_assessments_on_assessment_session_id"
    t.index ["coach_profile_id"], name: "index_assessments_on_coach_profile_id"
    t.index ["created_by_id"], name: "index_assessments_on_created_by_id"
    t.index ["discipline_id"], name: "index_assessments_on_discipline_id"
    t.index ["player_profile_id", "created_at"], name: "index_assessments_on_player_profile_id_and_created_at"
    t.index ["player_profile_id"], name: "index_assessments_on_player_profile_id"
    t.index ["status"], name: "index_assessments_on_status"
    t.index ["training_session_id"], name: "index_assessments_on_training_session_id"
    t.check_constraint "assessment_definition_id IS NOT NULL OR (score IS NULL) = (reported_value IS NULL)", name: "assessments_score_pair"
    t.check_constraint "assessment_definition_id IS NOT NULL OR discipline_id IS NOT NULL AND custom_discipline IS NULL OR discipline_id IS NULL AND custom_discipline IS NOT NULL", name: "assessments_discipline_xor_custom_discipline"
    t.check_constraint "assessment_definition_id IS NULL OR discipline_id IS NULL AND custom_discipline IS NULL", name: "assessment_definition_xor_rubric"
    t.check_constraint "score IS NULL OR score >= 0 AND score <= 100", name: "assessments_score_range"
    t.check_constraint "status::text = 'draft'::text OR score IS NOT NULL AND (assessment_definition_id IS NOT NULL OR reported_value IS NOT NULL)", name: "assessments_published_requires_score"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'withdrawn'::character varying::text])", name: "assessments_status"
  end

  create_table "claim_invitations", force: :cascade do |t|
    t.string "claimable_type", null: false
    t.bigint "claimable_id", null: false
    t.bigint "invited_by_id", null: false
    t.bigint "used_by_id"
    t.string "invitee_email"
    t.datetime "emailed_at"
    t.string "token_digest", null: false
    t.string "status", default: "active", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "declined_at"
    t.index ["claimable_type", "claimable_id"], name: "index_claim_invitations_on_claimable"
    t.index ["claimable_type", "claimable_id"], name: "index_claim_invitations_one_active_per_subject", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["invited_by_id"], name: "index_claim_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_claim_invitations_on_token_digest", unique: true
    t.index ["used_by_id"], name: "index_claim_invitations_on_used_by_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'used'::character varying::text, 'revoked'::character varying::text, 'expired'::character varying::text, 'declined'::character varying::text])", name: "claim_invitations_valid_status"
  end

  create_table "coach_profiles", force: :cascade do |t|
    t.string "coaching_level"
    t.text "qualifications"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "shared", null: false
    t.bigint "created_by_id"
    t.string "display_name"
    t.bigint "created_by_account_id"
    t.datetime "archived_at"
    t.bigint "merged_into_profile_id"
    t.datetime "merged_at"
    t.bigint "merged_by_account_id"
    t.bigint "account_id"
    t.string "email"
    t.index ["account_id"], name: "index_coach_profiles_on_account_id"
    t.index ["created_by_account_id"], name: "index_coach_profiles_on_created_by_account_id"
    t.index ["created_by_id"], name: "index_coach_profiles_on_created_by_id"
    t.index ["merged_by_account_id"], name: "index_coach_profiles_on_merged_by_account_id"
    t.index ["merged_into_profile_id"], name: "index_coach_profiles_on_merged_into_profile_id"
    t.index ["status"], name: "index_coach_profiles_on_status"
    t.index ["visibility"], name: "index_coach_profiles_on_visibility"
    t.check_constraint "merged_at IS NULL OR merged_into_profile_id IS NOT NULL AND archived_at IS NOT NULL", name: "coach_profiles_merge_state_consistent"
  end

  create_table "contact_details", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.date "date_of_birth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_contact_details_on_account_id", unique: true
  end

  create_table "courts", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.text "access_instructions"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "normalized_name"], name: "index_courts_on_location_id_and_normalized_name", unique: true
    t.index ["location_id"], name: "index_courts_on_location_id"
    t.check_constraint "(latitude IS NULL) = (longitude IS NULL)", name: "courts_coordinates_pair"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "courts_latitude_range"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "courts_longitude_range"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'archived'::character varying::text])", name: "courts_status"
  end

  create_table "criteria", force: :cascade do |t|
    t.bigint "assessment_category_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_category_id", "name"], name: "index_criteria_on_assessment_category_id_and_name", unique: true
    t.index ["assessment_category_id", "position"], name: "index_criteria_on_assessment_category_id_and_position"
    t.index ["assessment_category_id"], name: "index_criteria_on_assessment_category_id"
    t.check_constraint "\"position\" >= 0", name: "criteria_position_non_negative"
  end

  create_table "discipline_customs", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "created_by_id"
    t.string "visibility", default: "shared", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id", "name"], name: "index_discipline_customs_on_creator_and_name", unique: true
    t.index ["created_by_id"], name: "index_discipline_customs_on_created_by_id"
    t.index ["visibility"], name: "index_discipline_customs_on_visibility"
    t.check_constraint "visibility::text = ANY (ARRAY['shared'::character varying::text, 'private'::character varying::text])", name: "discipline_customs_visibility"
  end

  create_table "disciplines", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["slug"], name: "index_disciplines_on_slug", unique: true
  end

  create_table "drill_skills", force: :cascade do |t|
    t.bigint "drill_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["drill_id", "skill_id"], name: "index_drill_skills_on_drill_id_and_skill_id", unique: true
    t.index ["skill_id"], name: "index_drill_skills_on_skill_id"
  end

  create_table "drills", force: :cascade do |t|
    t.string "title"
    t.text "setup_instructions"
    t.integer "ideal_num_players"
    t.string "difficulty_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.string "training_stage"
    t.integer "min_players"
    t.integer "max_players"
    t.string "slug"
    t.jsonb "definition", default: {}, null: false
    t.string "visibility", default: "shared", null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.index ["created_by_id"], name: "index_drills_on_created_by_id"
    t.index ["slug"], name: "index_drills_on_slug", unique: true
    t.index ["status"], name: "index_drills_on_status"
    t.index ["training_stage"], name: "index_drills_on_training_stage"
    t.index ["visibility"], name: "index_drills_on_visibility"
    t.check_constraint "difficulty_level IS NULL OR (difficulty_level::text = ANY (ARRAY['beginner'::character varying::text, 'intermediate'::character varying::text, 'advanced'::character varying::text]))", name: "drills_difficulty_level_check"
    t.check_constraint "ideal_num_players IS NULL OR min_players IS NULL OR max_players IS NULL OR ideal_num_players >= min_players AND ideal_num_players <= max_players", name: "drills_ideal_players_check"
    t.check_constraint "min_players IS NULL OR max_players IS NULL OR min_players <= max_players", name: "drills_player_range_check"
    t.check_constraint "training_stage IS NULL OR (training_stage::text = ANY (ARRAY['warmup'::character varying::text, 'beginning'::character varying::text, 'middle'::character varying::text, 'end'::character varying::text]))", name: "drills_training_stage_check"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "active", null: false
    t.datetime "joined_at"
    t.datetime "left_at"
    t.bigint "account_id"
    t.string "memberable_type", null: false
    t.bigint "memberable_id", null: false
    t.index ["account_id"], name: "index_group_memberships_on_account_id"
    t.index ["group_id", "account_id"], name: "index_group_memberships_on_group_and_account", unique: true, where: "(account_id IS NOT NULL)"
    t.index ["group_id", "memberable_type", "memberable_id"], name: "index_group_memberships_on_subject", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["group_id"], name: "index_group_memberships_single_active_owner", unique: true, where: "(((role)::text = 'owner'::text) AND ((status)::text = 'active'::text))"
    t.index ["memberable_type", "memberable_id"], name: "index_group_memberships_on_memberable"
    t.check_constraint "left_at IS NULL OR status::text = 'ended'::text AND left_at IS NOT NULL", name: "group_memberships_left_at_when_ended"
    t.check_constraint "role::text = ANY (ARRAY['owner'::text, 'coach'::text, 'member'::text])", name: "group_memberships_role"
    t.check_constraint "status::text = ANY (ARRAY['pending'::text, 'active'::text, 'ended'::text])", name: "group_memberships_status"
  end

  create_table "groups", force: :cascade do |t|
    t.bigint "created_by_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "visibility", default: "shared", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organisation_id"
    t.boolean "requires_approval", default: false, null: false
    t.bigint "default_location_id"
    t.index "lower((name)::text)", name: "index_groups_on_lower_name", unique: true
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
    t.index ["default_location_id"], name: "index_groups_on_default_location_id"
    t.index ["name"], name: "index_groups_on_name"
    t.index ["organisation_id"], name: "index_groups_on_organisation_id"
    t.index ["slug"], name: "index_groups_on_slug", unique: true
    t.index ["status"], name: "index_groups_on_status"
    t.index ["visibility"], name: "index_groups_on_visibility"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'archived'::character varying::text])", name: "groups_status"
    t.check_constraint "visibility::text = ANY (ARRAY['shared'::character varying::text, 'private'::character varying::text])", name: "groups_visibility"
  end

  create_table "location_aliases", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "normalized_name"], name: "index_location_aliases_unique_name", unique: true
    t.index ["location_id"], name: "index_location_aliases_on_location_id"
    t.index ["normalized_name"], name: "index_location_aliases_on_normalized_name"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "location_type", default: "beach", null: false
    t.string "formatted_address"
    t.string "locality"
    t.string "administrative_area"
    t.string "country_code", limit: 2
    t.string "timezone"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "status", default: "active", null: false
    t.string "verification_status", default: "proposed", null: false
    t.string "geocoding_status", default: "not_requested", null: false
    t.string "source"
    t.string "source_reference"
    t.string "coordinate_source"
    t.bigint "proposed_by_account_id"
    t.bigint "verified_by_account_id"
    t.datetime "verified_at"
    t.datetime "archived_at"
    t.bigint "merged_into_id"
    t.text "internal_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", null: false
    t.index ["locality", "administrative_area", "country_code"], name: "index_locations_on_locality_scope"
    t.index ["merged_into_id"], name: "index_locations_on_merged_into_id"
    t.index ["normalized_name"], name: "index_locations_on_normalized_name"
    t.index ["proposed_by_account_id"], name: "index_locations_on_proposed_by_account_id"
    t.index ["slug"], name: "index_locations_on_slug", unique: true
    t.index ["status", "verification_status"], name: "index_locations_on_status_and_verification_status"
    t.index ["verified_by_account_id"], name: "index_locations_on_verified_by_account_id"
    t.check_constraint "(latitude IS NULL) = (longitude IS NULL)", name: "locations_coordinates_pair"
    t.check_constraint "geocoding_status::text = ANY (ARRAY['not_requested'::character varying::text, 'pending'::character varying::text, 'resolved'::character varying::text, 'failed'::character varying::text, 'manual'::character varying::text])", name: "locations_geocoding_status"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "locations_latitude_range"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "locations_longitude_range"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'archived'::character varying::text, 'merged'::character varying::text])", name: "locations_status"
    t.check_constraint "verification_status::text = ANY (ARRAY['proposed'::character varying::text, 'verified'::character varying::text, 'rejected'::character varying::text])", name: "locations_verification_status"
  end

  create_table "log_objects", force: :cascade do |t|
    t.bigint "log_id", null: false
    t.string "object_type", null: false
    t.bigint "object_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["log_id"], name: "index_log_objects_on_log_id"
    t.index ["object_type", "object_id"], name: "index_log_objects_on_object"
    t.index ["object_type", "object_id"], name: "index_log_objects_on_object_type_and_object_id"
  end

  create_table "logs", force: :cascade do |t|
    t.string "description", null: false
    t.bigint "user_id"
    t.string "action", null: false
    t.string "method", null: false
    t.string "path"
    t.string "ip_address"
    t.text "user_agent"
    t.string "request_id"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_logs_on_action_and_created_at"
    t.index ["created_at"], name: "index_logs_on_created_at"
    t.index ["request_id"], name: "index_logs_on_request_id"
    t.index ["user_id", "created_at"], name: "index_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_logs_on_user_id"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "in_app_enabled", default: true, null: false
    t.boolean "email_enabled", default: false, null: false
    t.string "email_cadence", default: "immediate", null: false
    t.jsonb "muted_event_types", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_notification_preferences_on_account_id", unique: true
    t.check_constraint "email_cadence::text = ANY (ARRAY['immediate'::character varying::text, 'daily'::character varying::text, 'weekly'::character varying::text, 'none'::character varying::text])", name: "notification_preferences_email_cadence"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "actor_account_id"
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "event_type", null: false
    t.string "event_key", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "target_path"
    t.string "target_label"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "read_at"
    t.datetime "emailed_at"
    t.datetime "email_failed_at"
    t.text "email_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_key"], name: "index_notifications_on_account_id_and_event_key", unique: true
    t.index ["account_id", "read_at", "created_at"], name: "index_notifications_inbox"
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["actor_account_id"], name: "index_notifications_on_actor_account_id"
    t.index ["event_type", "created_at"], name: "index_notifications_on_event_type_and_created_at"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
  end

  create_table "organisation_locations", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "location_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_organisation_locations_on_location_id"
    t.index ["organisation_id", "location_id"], name: "index_organisation_locations_unique", unique: true
    t.index ["organisation_id"], name: "index_organisation_locations_on_organisation_id"
  end

  create_table "organisation_memberships", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "pending", null: false
    t.datetime "joined_at"
    t.datetime "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id"
    t.string "memberable_type", null: false
    t.bigint "memberable_id", null: false
    t.index ["account_id"], name: "index_organisation_memberships_on_account_id"
    t.index ["memberable_type", "memberable_id"], name: "index_organisation_memberships_on_memberable"
    t.index ["organisation_id", "account_id"], name: "index_org_memberships_on_org_and_account", unique: true, where: "(account_id IS NOT NULL)"
    t.index ["organisation_id", "memberable_type", "memberable_id"], name: "index_organisation_memberships_on_subject", unique: true
    t.index ["organisation_id", "status"], name: "index_org_memberships_on_organisation_and_status"
    t.index ["organisation_id"], name: "index_org_memberships_single_active_owner", unique: true, where: "(((role)::text = 'owner'::text) AND ((status)::text = 'active'::text))"
    t.index ["organisation_id"], name: "index_organisation_memberships_on_organisation_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying::text, 'administrator'::character varying::text, 'coach'::character varying::text, 'member'::character varying::text])", name: "organisation_memberships_role"
    t.check_constraint "status::text <> 'ended'::text OR left_at IS NOT NULL", name: "organisation_memberships_ended_has_left_at"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'active'::character varying::text, 'suspended'::character varying::text, 'ended'::character varying::text])", name: "organisation_memberships_status"
  end

  create_table "organisations", force: :cascade do |t|
    t.bigint "parent_organisation_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "organisation_type", default: "other", null: false
    t.text "description"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "acronym"
    t.bigint "created_by_account_id"
    t.boolean "requires_approval", default: false, null: false
    t.bigint "default_location_id"
    t.index "lower((name)::text)", name: "index_organisations_on_lower_name", unique: true
    t.index ["acronym"], name: "index_organisations_on_acronym"
    t.index ["created_by_account_id"], name: "index_organisations_on_created_by_account_id"
    t.index ["default_location_id"], name: "index_organisations_on_default_location_id"
    t.index ["organisation_type"], name: "index_organisations_on_organisation_type"
    t.index ["parent_organisation_id"], name: "index_organisations_on_parent_organisation_id"
    t.index ["slug"], name: "index_organisations_on_slug", unique: true
    t.index ["status"], name: "index_organisations_on_status"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'archived'::character varying::text])", name: "organisations_status"
  end

  create_table "player_claims", force: :cascade do |t|
    t.bigint "player_profile_id"
    t.string "status", default: "pending", null: false
    t.datetime "reviewed_at"
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "claimable_type"
    t.bigint "claimable_id"
    t.bigint "claimant_account_id"
    t.bigint "reviewed_by_account_id"
    t.string "verification_method"
    t.bigint "initiated_by_account_id"
    t.index ["claimable_type", "claimable_id", "claimant_account_id"], name: "index_player_claims_pending_per_account_and_claimable", unique: true, where: "(((status)::text = 'pending'::text) AND (claimant_account_id IS NOT NULL))"
    t.index ["claimable_type", "claimable_id"], name: "index_player_claims_on_claimable"
    t.index ["claimant_account_id"], name: "index_player_claims_on_claimant_account_id"
    t.index ["initiated_by_account_id"], name: "index_player_claims_on_initiated_by_account_id"
    t.index ["player_profile_id"], name: "index_player_claims_on_player_profile_id"
    t.index ["reviewed_by_account_id"], name: "index_player_claims_on_reviewed_by_account_id"
    t.check_constraint "claimable_id IS NOT NULL AND player_profile_id IS NULL OR claimable_id IS NULL AND player_profile_id IS NOT NULL", name: "player_claims_single_subject"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text, 'cancelled'::character varying::text])", name: "player_claims_valid_status"
    t.check_constraint "verification_method IS NULL OR (verification_method::text = ANY (ARRAY['staff_confirmed'::character varying::text, 'government_id'::character varying::text, 'in_person'::character varying::text, 'other'::character varying::text]))", name: "player_claims_valid_verification_method"
  end

  create_table "player_coaches", force: :cascade do |t|
    t.bigint "player_profile_id", null: false
    t.bigint "coach_profile_id", null: false
    t.date "start_date", null: false
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coach_profile_id", "end_date"], name: "index_player_coaches_on_coach_and_end"
    t.index ["coach_profile_id"], name: "index_player_coaches_on_coach_profile_id"
    t.index ["player_profile_id", "coach_profile_id", "start_date"], name: "index_player_coaches_pair_and_start", unique: true
    t.index ["player_profile_id", "coach_profile_id"], name: "index_player_coaches_single_current_per_pair", unique: true, where: "(end_date IS NULL)"
    t.index ["player_profile_id", "end_date"], name: "index_player_coaches_on_player_and_end"
    t.index ["player_profile_id"], name: "index_player_coaches_on_player_profile_id"
    t.check_constraint "end_date IS NULL OR end_date >= start_date", name: "player_coaches_end_after_start"
  end

  create_table "player_profiles", force: :cascade do |t|
    t.string "preferred_position"
    t.string "level"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "shared", null: false
    t.bigint "created_by_id"
    t.string "display_name"
    t.bigint "created_by_account_id"
    t.datetime "archived_at"
    t.bigint "merged_into_profile_id"
    t.datetime "merged_at"
    t.bigint "merged_by_account_id"
    t.bigint "account_id"
    t.string "email"
    t.index ["account_id"], name: "index_player_profiles_on_account_id"
    t.index ["created_by_account_id"], name: "index_player_profiles_on_created_by_account_id"
    t.index ["created_by_id"], name: "index_player_profiles_on_created_by_id"
    t.index ["merged_by_account_id"], name: "index_player_profiles_on_merged_by_account_id"
    t.index ["merged_into_profile_id"], name: "index_player_profiles_on_merged_into_profile_id"
    t.index ["status"], name: "index_player_profiles_on_status"
    t.index ["visibility"], name: "index_player_profiles_on_visibility"
    t.check_constraint "merged_at IS NULL OR merged_into_profile_id IS NOT NULL AND archived_at IS NOT NULL", name: "player_profiles_merge_state_consistent"
  end

  create_table "profile_merges", force: :cascade do |t|
    t.string "source_profile_type", null: false
    t.bigint "source_profile_id", null: false
    t.string "canonical_profile_type", null: false
    t.bigint "canonical_profile_id", null: false
    t.bigint "merged_by_account_id", null: false
    t.text "reason", null: false
    t.jsonb "reference_counts", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_profile_type", "canonical_profile_id"], name: "index_profile_merges_canonical"
    t.index ["merged_by_account_id"], name: "index_profile_merges_on_merged_by_account_id"
    t.index ["source_profile_type", "source_profile_id"], name: "index_profile_merges_unique_source", unique: true
    t.check_constraint "source_profile_type::text = canonical_profile_type::text AND source_profile_id <> canonical_profile_id", name: "profile_merges_distinct_same_type"
  end

  create_table "ranking_consolidation_rows", force: :cascade do |t|
    t.bigint "ranking_consolidation_id", null: false
    t.bigint "player_profile_id", null: false
    t.jsonb "coach_scores", default: {}, null: false
    t.integer "coverage", default: 0, null: false
    t.integer "average_score"
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_profile_id"], name: "index_ranking_consolidation_rows_on_player_profile_id"
    t.index ["ranking_consolidation_id", "player_profile_id"], name: "index_consolidation_rows_on_consolidation_and_player", unique: true
    t.index ["ranking_consolidation_id"], name: "index_ranking_consolidation_rows_on_ranking_consolidation_id"
  end

  create_table "ranking_consolidation_sessions", force: :cascade do |t|
    t.bigint "ranking_consolidation_id", null: false
    t.bigint "assessment_session_id", null: false
    t.jsonb "ranking_snapshot", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "excluded_from_snapshot", default: false, null: false
    t.index ["assessment_session_id"], name: "index_ranking_consolidation_sessions_on_assessment_session_id"
    t.index ["ranking_consolidation_id", "assessment_session_id"], name: "index_consolidation_sessions_on_consolidation_and_session", unique: true
    t.index ["ranking_consolidation_id"], name: "idx_on_ranking_consolidation_id_c8618d652c"
  end

  create_table "ranking_consolidations", force: :cascade do |t|
    t.bigint "assessment_definition_id", null: false
    t.bigint "created_by_id"
    t.string "name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "source_warnings", default: [], null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "recalculated_at"
    t.bigint "recalculated_by_id"
    t.index ["assessment_definition_id"], name: "index_ranking_consolidations_on_assessment_definition_id"
    t.index ["created_by_id"], name: "index_ranking_consolidations_on_created_by_id"
    t.index ["recalculated_by_id"], name: "index_ranking_consolidations_on_recalculated_by_id"
    t.index ["status"], name: "index_ranking_consolidations_on_status"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'withdrawn'::character varying::text])", name: "ranking_consolidations_status"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_token"
    t.datetime "api_token_expires_at"
    t.bigint "impersonated_user_id"
    t.index ["api_token"], name: "index_sessions_on_api_token", unique: true
    t.index ["impersonated_user_id"], name: "index_sessions_on_impersonated_user_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "skills", force: :cascade do |t|
    t.string "title"
    t.bigint "discipline_id", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.string "slug"
    t.string "visibility", default: "shared", null: false
    t.string "status", default: "published", null: false
    t.datetime "published_at"
    t.index ["created_by_id"], name: "index_skills_on_created_by_id"
    t.index ["discipline_id"], name: "index_skills_on_discipline_id"
    t.index ["slug"], name: "index_skills_on_slug", unique: true
    t.index ["status"], name: "index_skills_on_status"
    t.index ["visibility"], name: "index_skills_on_visibility"
  end

  create_table "tournament_divisions", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.string "letter_level"
    t.integer "division_number"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_tournament_divisions_on_active"
    t.index ["division_number"], name: "index_tournament_divisions_on_division_number"
    t.index ["letter_level"], name: "index_tournament_divisions_on_letter_level"
    t.index ["tournament_id", "division_number"], name: "index_tournament_divisions_on_tournament_id_and_division_number", unique: true, where: "(division_number IS NOT NULL)"
    t.index ["tournament_id", "letter_level"], name: "index_tournament_divisions_on_tournament_id_and_letter_level", unique: true, where: "(letter_level IS NOT NULL)"
    t.index ["tournament_id"], name: "index_tournament_divisions_on_tournament_id"
    t.check_constraint "division_number IS NULL OR division_number > 0", name: "division_number_positive"
    t.check_constraint "letter_level IS NOT NULL AND division_number IS NULL OR letter_level IS NULL AND division_number IS NOT NULL", name: "division_level_or_number"
    t.check_constraint "letter_level IS NULL OR (letter_level::text = ANY (ARRAY['B'::character varying::text, 'BB'::character varying::text, 'BBB'::character varying::text, 'A'::character varying::text, 'AA'::character varying::text, 'AAA'::character varying::text, 'AAAA'::character varying::text]))", name: "valid_letter_level"
  end

  create_table "tournament_follows", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "tournament_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "tournament_id"], name: "index_tournament_follows_on_account_id_and_tournament_id", unique: true
    t.index ["account_id"], name: "index_tournament_follows_on_account_id"
    t.index ["tournament_id"], name: "index_tournament_follows_on_tournament_id"
  end

  create_table "tournament_participation_divisions", force: :cascade do |t|
    t.bigint "tournament_participation_id", null: false
    t.bigint "tournament_division_id", null: false
    t.bigint "tournament_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_division_id"], name: "idx_on_tournament_division_id_3fea2c228f"
    t.index ["tournament_id"], name: "index_tournament_participation_divisions_on_tournament_id"
    t.index ["tournament_participation_id", "tournament_division_id"], name: "idx_on_tournament_participation_id_tournament_divis_cb1066220f", unique: true
    t.index ["tournament_participation_id"], name: "idx_on_tournament_participation_id_b11fb1a51c"
  end

  create_table "tournament_participations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "tournament_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_tournament_participations_on_account_id"
    t.index ["role"], name: "index_tournament_participations_on_role"
    t.index ["tournament_id"], name: "index_tournament_participations_on_tournament_id"
  end

  create_table "tournament_watch_links", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.string "name", null: false
    t.string "url", null: false
    t.string "provider"
    t.text "description"
    t.datetime "starts_at"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_tournament_watch_links_on_position"
    t.index ["tournament_id"], name: "index_tournament_watch_links_on_tournament_id"
    t.check_constraint "url::text ~* '^https?://'::text", name: "valid_url"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "organisation_id", null: false
    t.string "scope", null: false
    t.string "division_scheme", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "timezone", null: false
    t.boolean "all_day", default: false, null: false
    t.text "description"
    t.string "location_name"
    t.string "website_url"
    t.string "publication_state", default: "draft", null: false
    t.bigint "created_by_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_id"
    t.bigint "court_id"
    t.string "location_detail"
    t.index ["court_id"], name: "index_tournaments_on_court_id"
    t.index ["created_by_account_id"], name: "index_tournaments_on_created_by_account_id"
    t.index ["ends_at"], name: "index_tournaments_on_ends_at"
    t.index ["location_id"], name: "index_tournaments_on_location_id"
    t.index ["organisation_id"], name: "index_tournaments_on_organisation_id"
    t.index ["publication_state"], name: "index_tournaments_on_publication_state"
    t.index ["starts_at"], name: "index_tournaments_on_starts_at"
    t.check_constraint "ends_at > starts_at", name: "ends_after_starts"
    t.check_constraint "publication_state::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'cancelled'::character varying::text, 'archived'::character varying::text])", name: "valid_publication_state"
    t.check_constraint "scope::text = ANY (ARRAY['club'::character varying::text, 'state'::character varying::text, 'national'::character varying::text, 'international'::character varying::text, 'other'::character varying::text])", name: "valid_scope"
  end

  create_table "training_focuses", force: :cascade do |t|
    t.bigint "training_session_id", null: false
    t.bigint "skill_id"
    t.string "custom_focus"
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_training_focuses_on_skill_id"
    t.index ["training_session_id", "position"], name: "index_training_focuses_on_training_session_id_and_position"
    t.index ["training_session_id", "skill_id"], name: "index_training_focuses_on_session_and_skill", unique: true
    t.index ["training_session_id"], name: "index_training_focuses_on_training_session_id"
    t.check_constraint "\"position\" >= 0", name: "training_focuses_position_non_negative"
    t.check_constraint "skill_id IS NOT NULL AND custom_focus IS NULL OR skill_id IS NULL AND custom_focus IS NOT NULL", name: "training_focuses_skill_xor_custom_focus"
  end

  create_table "training_series", force: :cascade do |t|
    t.bigint "training_template_id", null: false
    t.bigint "organisation_id"
    t.bigint "created_by_id"
    t.string "frequency", default: "weekly", null: false
    t.integer "interval", default: 1, null: false
    t.string "weekdays", default: [], null: false, array: true
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.time "local_start_time", null: false
    t.integer "duration_minutes", null: false
    t.string "time_zone", default: "Australia/Sydney", null: false
    t.string "status", default: "active", null: false
    t.date "generated_through"
    t.jsonb "defaults_snapshot", default: {}, null: false
    t.datetime "last_generated_at"
    t.datetime "stopped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "stopped_reason"
    t.index ["created_by_id"], name: "index_training_series_on_created_by_id"
    t.index ["organisation_id"], name: "index_training_series_on_organisation_id"
    t.index ["starts_on"], name: "index_training_series_on_starts_on"
    t.index ["status"], name: "index_training_series_on_status"
    t.index ["training_template_id", "status"], name: "index_training_series_on_training_template_id_and_status"
    t.index ["training_template_id"], name: "index_training_series_on_training_template_id"
    t.check_constraint "\"interval\" >= 1", name: "training_series_interval_positive"
    t.check_constraint "array_length(weekdays, 1) >= 1", name: "training_series_weekdays_present"
    t.check_constraint "duration_minutes > 0", name: "training_series_duration_positive"
    t.check_constraint "ends_on >= starts_on", name: "training_series_ends_on_after_starts_on"
    t.check_constraint "frequency::text = 'weekly'::text", name: "training_series_frequency"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'stopped'::character varying::text])", name: "training_series_status"
    t.check_constraint "weekdays <@ ARRAY['mon'::character varying, 'tue'::character varying, 'wed'::character varying, 'thu'::character varying, 'fri'::character varying, 'sat'::character varying, 'sun'::character varying]", name: "training_series_weekdays_valid"
  end

  create_table "training_session_drills", force: :cascade do |t|
    t.bigint "training_session_id", null: false
    t.bigint "drill_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "duration_minutes"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["drill_id"], name: "index_training_session_drills_on_drill_id"
    t.index ["training_session_id", "drill_id"], name: "index_training_session_drills_on_session_and_drill", unique: true
    t.index ["training_session_id", "position"], name: "index_training_session_drills_on_session_and_position"
    t.index ["training_session_id"], name: "index_training_session_drills_on_training_session_id"
    t.check_constraint "\"position\" >= 0", name: "training_session_drills_position_non_negative"
    t.check_constraint "duration_minutes IS NULL OR duration_minutes > 0", name: "training_session_drills_duration_minutes_positive"
  end

  create_table "training_session_participants", force: :cascade do |t|
    t.bigint "training_session_id", null: false
    t.bigint "player_profile_id", null: false
    t.string "status", default: "invited", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "cancellation_notified_at"
    t.index ["player_profile_id"], name: "index_training_session_participants_on_player_profile_id"
    t.index ["status"], name: "index_training_session_participants_on_status"
    t.index ["training_session_id", "player_profile_id"], name: "index_training_session_participants_on_session_and_player", unique: true
    t.index ["training_session_id"], name: "index_training_session_participants_on_training_session_id"
  end

  create_table "training_sessions", force: :cascade do |t|
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.string "title", null: false
    t.text "description"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "draft", null: false
    t.string "visibility", default: "shared", null: false
    t.bigint "training_series_id"
    t.bigint "training_template_id"
    t.bigint "organisation_id", null: false
    t.bigint "group_id"
    t.bigint "coach_profile_id"
    t.bigint "cancelled_by_id"
    t.integer "capacity"
    t.string "level"
    t.string "location_detail"
    t.string "recurrence_key"
    t.datetime "original_starts_at"
    t.jsonb "override_fields", default: {}, null: false
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "location_id"
    t.bigint "court_id"
    t.index ["cancelled_by_id"], name: "index_training_sessions_on_cancelled_by_id"
    t.index ["coach_profile_id"], name: "index_training_sessions_on_coach_profile_id"
    t.index ["court_id"], name: "index_training_sessions_on_court_id"
    t.index ["created_by_id"], name: "index_training_sessions_on_created_by_id"
    t.index ["group_id"], name: "index_training_sessions_on_group_id"
    t.index ["location_id"], name: "index_training_sessions_on_location_id"
    t.index ["organisation_id"], name: "index_training_sessions_on_organisation_id"
    t.index ["starts_at"], name: "index_training_sessions_on_starts_at"
    t.index ["status"], name: "index_training_sessions_on_status"
    t.index ["training_series_id", "recurrence_key"], name: "index_training_sessions_on_series_and_recurrence_key", unique: true, where: "((training_series_id IS NOT NULL) AND (recurrence_key IS NOT NULL))"
    t.index ["training_series_id", "starts_at"], name: "index_training_sessions_on_series_and_starts_at"
    t.index ["training_series_id"], name: "index_training_sessions_on_training_series_id"
    t.index ["training_template_id"], name: "index_training_sessions_on_training_template_id"
    t.index ["visibility"], name: "index_training_sessions_on_visibility"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "training_sessions_capacity_positive"
    t.check_constraint "ends_at > starts_at", name: "training_sessions_ends_at_after_starts_at"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'scheduled'::character varying::text, 'cancelled'::character varying::text, 'completed'::character varying::text])", name: "training_sessions_status"
    t.check_constraint "training_series_id IS NULL OR recurrence_key IS NOT NULL", name: "training_sessions_series_requires_recurrence_key"
  end

  create_table "training_templates", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "organisation_id", null: false
    t.bigint "group_id"
    t.bigint "coach_profile_id"
    t.string "location"
    t.string "location_detail"
    t.string "level"
    t.integer "capacity"
    t.integer "duration_minutes", default: 90, null: false
    t.string "visibility", default: "shared", null: false
    t.string "status", default: "active", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_id"
    t.index ["coach_profile_id"], name: "index_training_templates_on_coach_profile_id"
    t.index ["created_by_id"], name: "index_training_templates_on_created_by_id"
    t.index ["group_id"], name: "index_training_templates_on_group_id"
    t.index ["location_id"], name: "index_training_templates_on_location_id"
    t.index ["name"], name: "index_training_templates_on_name"
    t.index ["organisation_id"], name: "index_training_templates_on_organisation_id"
    t.index ["status"], name: "index_training_templates_on_status"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "training_templates_capacity_positive"
    t.check_constraint "duration_minutes > 0", name: "training_templates_duration_positive"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'archived'::character varying::text])", name: "training_templates_status"
    t.check_constraint "visibility::text = ANY (ARRAY['shared'::character varying::text, 'private'::character varying::text])", name: "training_templates_visibility"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_verified_at"
    t.string "email_verification_token_digest"
    t.datetime "email_verification_sent_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["email_verification_token_digest"], name: "index_users_on_email_verification_token_digest"
  end

  create_table "video_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["created_by_id"], name: "index_video_categories_on_created_by_id"
    t.index ["name"], name: "index_video_categories_on_name", unique: true
    t.index ["position"], name: "index_video_categories_on_position"
    t.index ["slug"], name: "index_video_categories_on_slug", unique: true
  end

  create_table "video_references", force: :cascade do |t|
    t.bigint "video_id", null: false
    t.string "referenced_type", null: false
    t.bigint "referenced_id", null: false
    t.integer "start_seconds"
    t.integer "end_seconds"
    t.string "title"
    t.text "description"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["referenced_type", "referenced_id", "position"], name: "index_video_references_on_referenced_and_position"
    t.index ["referenced_type", "referenced_id"], name: "index_video_references_on_referenced"
    t.index ["video_id"], name: "index_video_references_on_video_id"
    t.check_constraint "end_seconds IS NULL OR end_seconds >= 0", name: "video_references_end_seconds_non_negative"
    t.check_constraint "end_seconds IS NULL OR start_seconds IS NULL OR end_seconds > start_seconds", name: "video_references_end_after_start"
    t.check_constraint "start_seconds IS NULL OR start_seconds >= 0", name: "video_references_start_seconds_non_negative"
  end

  create_table "video_taggings", force: :cascade do |t|
    t.bigint "video_id", null: false
    t.bigint "video_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["video_id", "video_tag_id"], name: "index_video_taggings_on_video_id_and_video_tag_id", unique: true
    t.index ["video_id"], name: "index_video_taggings_on_video_id"
    t.index ["video_tag_id"], name: "index_video_taggings_on_video_tag_id"
  end

  create_table "video_tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", default: 0, null: false
    t.index "lower((name)::text)", name: "index_video_tags_on_lower_name", unique: true
    t.index ["name"], name: "index_video_tags_on_name", unique: true
    t.index ["position"], name: "index_video_tags_on_position"
  end

  create_table "videos", force: :cascade do |t|
    t.string "provider", null: false
    t.string "provider_video_id"
    t.string "source_url"
    t.string "storage_key"
    t.string "title"
    t.text "description"
    t.integer "duration_seconds"
    t.string "thumbnail_url"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "video_category_id"
    t.string "visibility", default: "shared", null: false
    t.string "status", default: "published", null: false
    t.datetime "published_at"
    t.index ["created_by_id"], name: "index_videos_on_created_by_id"
    t.index ["provider", "provider_video_id"], name: "index_videos_on_provider_and_provider_video_id", unique: true, where: "(provider_video_id IS NOT NULL)"
    t.index ["provider"], name: "index_videos_on_provider"
    t.index ["provider_video_id"], name: "index_videos_on_provider_video_id"
    t.index ["status"], name: "index_videos_on_status"
    t.index ["visibility"], name: "index_videos_on_visibility"
  end

  create_table "weather_advisor_preferences", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "wind_weight", default: 40, null: false
    t.integer "temperature_weight", default: 20, null: false
    t.integer "rain_weight", default: 25, null: false
    t.integer "uv_weight", default: 5, null: false
    t.integer "humidity_weight", default: 10, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_weather_advisor_preferences_on_account_id", unique: true
    t.check_constraint "(wind_weight + temperature_weight + rain_weight + uv_weight + humidity_weight) = 100", name: "weather_advisor_preferences_weights_total"
    t.check_constraint "humidity_weight >= 0 AND humidity_weight <= 100", name: "weather_advisor_preferences_humidity_weight_range"
    t.check_constraint "rain_weight >= 0 AND rain_weight <= 100", name: "weather_advisor_preferences_rain_weight_range"
    t.check_constraint "temperature_weight >= 0 AND temperature_weight <= 100", name: "weather_advisor_preferences_temperature_weight_range"
    t.check_constraint "uv_weight >= 0 AND uv_weight <= 100", name: "weather_advisor_preferences_uv_weight_range"
    t.check_constraint "wind_weight >= 0 AND wind_weight <= 100", name: "weather_advisor_preferences_wind_weight_range"
  end

  create_table "weather_share_snapshots", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "public_token", null: false
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.string "location_name", null: false
    t.datetime "forecast_target_time"
    t.string "timezone"
    t.jsonb "weather_data", null: false
    t.integer "volleyball_score"
    t.string "volleyball_label"
    t.jsonb "volleyball_warnings", default: []
    t.jsonb "volleyball_advice", default: []
    t.boolean "volleyball_safety_override", default: false
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_weather_share_snapshots_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_weather_share_snapshots_on_account_id"
    t.index ["expires_at"], name: "index_weather_share_snapshots_on_expires_at"
    t.index ["public_token"], name: "index_weather_share_snapshots_on_public_token", unique: true
    t.index ["revoked_at"], name: "index_weather_share_snapshots_on_revoked_at"
  end

  add_foreign_key "account_addresses", "accounts"
  add_foreign_key "account_invitations", "users", column: "invited_by_id"
  add_foreign_key "account_invitations", "users", column: "used_by_id"
  add_foreign_key "accounts", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_activities", "users"
  add_foreign_key "analyses", "coach_profiles", column: "assigned_coach_profile_id", on_delete: :nullify
  add_foreign_key "analyses", "groups", on_delete: :nullify
  add_foreign_key "analyses", "organisations", on_delete: :nullify
  add_foreign_key "analyses", "tournaments", on_delete: :nullify
  add_foreign_key "analyses", "training_sessions", on_delete: :nullify
  add_foreign_key "analyses", "users", column: "created_by_id", on_delete: :restrict
  add_foreign_key "analysis_annotations", "analysis_videos", on_delete: :cascade
  add_foreign_key "analysis_annotations", "player_profiles", on_delete: :nullify
  add_foreign_key "analysis_annotations", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "analysis_assessment_sessions", "analyses", on_delete: :cascade
  add_foreign_key "analysis_assessment_sessions", "assessment_sessions", on_delete: :cascade
  add_foreign_key "analysis_comments", "analyses", on_delete: :cascade
  add_foreign_key "analysis_comments", "analysis_comments", column: "parent_id", on_delete: :cascade
  add_foreign_key "analysis_comments", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "analysis_participants", "analyses", on_delete: :cascade
  add_foreign_key "analysis_participants", "player_profiles", on_delete: :restrict
  add_foreign_key "analysis_videos", "analyses", on_delete: :cascade
  add_foreign_key "analysis_videos", "videos", on_delete: :nullify
  add_foreign_key "assessment_categories", "assessment_definitions"
  add_foreign_key "assessment_categories", "discipline_customs"
  add_foreign_key "assessment_categories", "disciplines"
  add_foreign_key "assessment_category_scores", "assessment_categories"
  add_foreign_key "assessment_category_scores", "assessments"
  add_foreign_key "assessment_category_scores", "criteria"
  add_foreign_key "assessment_definitions", "users", column: "created_by_id"
  add_foreign_key "assessment_session_participants", "assessment_sessions"
  add_foreign_key "assessment_session_participants", "player_profiles"
  add_foreign_key "assessment_sessions", "assessment_definitions"
  add_foreign_key "assessment_sessions", "coach_profiles"
  add_foreign_key "assessment_sessions", "groups"
  add_foreign_key "assessment_sessions", "users", column: "created_by_id"
  add_foreign_key "assessments", "assessment_definitions"
  add_foreign_key "assessments", "assessment_sessions", on_delete: :nullify
  add_foreign_key "assessments", "coach_profiles"
  add_foreign_key "assessments", "disciplines"
  add_foreign_key "assessments", "player_profiles"
  add_foreign_key "assessments", "training_sessions", on_delete: :nullify
  add_foreign_key "assessments", "users", column: "created_by_id"
  add_foreign_key "claim_invitations", "users", column: "invited_by_id"
  add_foreign_key "claim_invitations", "users", column: "used_by_id"
  add_foreign_key "coach_profiles", "accounts", column: "created_by_account_id"
  add_foreign_key "coach_profiles", "accounts", column: "merged_by_account_id"
  add_foreign_key "coach_profiles", "accounts", on_delete: :restrict
  add_foreign_key "coach_profiles", "coach_profiles", column: "merged_into_profile_id"
  add_foreign_key "coach_profiles", "users", column: "created_by_id"
  add_foreign_key "contact_details", "accounts", on_delete: :restrict
  add_foreign_key "courts", "locations"
  add_foreign_key "criteria", "assessment_categories"
  add_foreign_key "discipline_customs", "users", column: "created_by_id"
  add_foreign_key "drill_skills", "drills"
  add_foreign_key "drill_skills", "skills"
  add_foreign_key "drills", "users", column: "approved_by_id"
  add_foreign_key "drills", "users", column: "created_by_id"
  add_foreign_key "group_memberships", "accounts"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "groups", "locations", column: "default_location_id"
  add_foreign_key "groups", "organisations"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "location_aliases", "locations"
  add_foreign_key "locations", "accounts", column: "proposed_by_account_id"
  add_foreign_key "locations", "accounts", column: "verified_by_account_id"
  add_foreign_key "locations", "locations", column: "merged_into_id"
  add_foreign_key "log_objects", "logs"
  add_foreign_key "notification_preferences", "accounts", on_delete: :cascade
  add_foreign_key "notifications", "accounts", column: "actor_account_id", on_delete: :nullify
  add_foreign_key "notifications", "accounts", on_delete: :cascade
  add_foreign_key "organisation_locations", "locations"
  add_foreign_key "organisation_locations", "organisations"
  add_foreign_key "organisation_memberships", "accounts"
  add_foreign_key "organisation_memberships", "organisations"
  add_foreign_key "organisations", "accounts", column: "created_by_account_id"
  add_foreign_key "organisations", "locations", column: "default_location_id"
  add_foreign_key "organisations", "organisations", column: "parent_organisation_id"
  add_foreign_key "player_claims", "accounts", column: "claimant_account_id"
  add_foreign_key "player_claims", "accounts", column: "initiated_by_account_id"
  add_foreign_key "player_claims", "accounts", column: "reviewed_by_account_id"
  add_foreign_key "player_claims", "player_profiles"
  add_foreign_key "player_coaches", "coach_profiles"
  add_foreign_key "player_coaches", "player_profiles"
  add_foreign_key "player_profiles", "accounts", column: "created_by_account_id"
  add_foreign_key "player_profiles", "accounts", column: "merged_by_account_id"
  add_foreign_key "player_profiles", "accounts", on_delete: :restrict
  add_foreign_key "player_profiles", "player_profiles", column: "merged_into_profile_id"
  add_foreign_key "player_profiles", "users", column: "created_by_id"
  add_foreign_key "profile_merges", "accounts", column: "merged_by_account_id"
  add_foreign_key "ranking_consolidation_rows", "player_profiles"
  add_foreign_key "ranking_consolidation_rows", "ranking_consolidations"
  add_foreign_key "ranking_consolidation_sessions", "assessment_sessions"
  add_foreign_key "ranking_consolidation_sessions", "ranking_consolidations"
  add_foreign_key "ranking_consolidations", "assessment_definitions"
  add_foreign_key "ranking_consolidations", "users", column: "created_by_id"
  add_foreign_key "ranking_consolidations", "users", column: "recalculated_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "users", column: "impersonated_user_id"
  add_foreign_key "skills", "disciplines"
  add_foreign_key "skills", "users", column: "created_by_id"
  add_foreign_key "tournament_divisions", "tournaments"
  add_foreign_key "tournament_follows", "accounts"
  add_foreign_key "tournament_follows", "tournaments"
  add_foreign_key "tournament_participation_divisions", "tournament_divisions"
  add_foreign_key "tournament_participation_divisions", "tournament_participations"
  add_foreign_key "tournament_participation_divisions", "tournaments"
  add_foreign_key "tournament_participations", "accounts"
  add_foreign_key "tournament_participations", "tournaments"
  add_foreign_key "tournament_watch_links", "tournaments"
  add_foreign_key "tournaments", "accounts", column: "created_by_account_id"
  add_foreign_key "tournaments", "courts"
  add_foreign_key "tournaments", "locations"
  add_foreign_key "tournaments", "organisations", on_delete: :restrict
  add_foreign_key "training_focuses", "skills"
  add_foreign_key "training_focuses", "training_sessions"
  add_foreign_key "training_series", "organisations", on_delete: :nullify
  add_foreign_key "training_series", "training_templates", on_delete: :restrict
  add_foreign_key "training_series", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "training_session_drills", "drills"
  add_foreign_key "training_session_drills", "training_sessions"
  add_foreign_key "training_session_participants", "player_profiles"
  add_foreign_key "training_session_participants", "training_sessions"
  add_foreign_key "training_sessions", "coach_profiles", on_delete: :nullify
  add_foreign_key "training_sessions", "courts"
  add_foreign_key "training_sessions", "groups", on_delete: :nullify
  add_foreign_key "training_sessions", "locations"
  add_foreign_key "training_sessions", "organisations", on_delete: :nullify
  add_foreign_key "training_sessions", "training_series", on_delete: :restrict
  add_foreign_key "training_sessions", "training_templates", on_delete: :restrict
  add_foreign_key "training_sessions", "users", column: "cancelled_by_id", on_delete: :nullify
  add_foreign_key "training_sessions", "users", column: "created_by_id"
  add_foreign_key "training_templates", "coach_profiles", on_delete: :nullify
  add_foreign_key "training_templates", "groups", on_delete: :nullify
  add_foreign_key "training_templates", "locations"
  add_foreign_key "training_templates", "organisations", on_delete: :nullify
  add_foreign_key "training_templates", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "video_categories", "users", column: "created_by_id"
  add_foreign_key "video_references", "videos"
  add_foreign_key "video_taggings", "video_tags"
  add_foreign_key "video_taggings", "videos"
  add_foreign_key "videos", "users", column: "created_by_id"
  add_foreign_key "videos", "video_categories", on_delete: :nullify
  add_foreign_key "weather_advisor_preferences", "accounts"
  add_foreign_key "weather_share_snapshots", "accounts"
end
