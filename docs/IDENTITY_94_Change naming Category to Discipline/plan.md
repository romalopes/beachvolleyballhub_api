# Plan to Rename “Category” → “Discipline”

## Overview
Rename the `Category` domain concept to `Discipline` across the entire codebase while preserving data integrity. Since all existing data will be ignored and the database will be reseeded, we can create fresh tables and models without worrying about migration complexities.

## Step‑by‑Step Plan

1. **Create the new `Discipline` model**
   - File: `app/models/discipline.rb`
   - Copy the existing `Category` model content.
   - Rename the class to `Discipline`.
   - Keep `include Sluggable` (or whatever modules `Category` includes) and the `source_column :name` (if needed).

2. **Create the new `DisciplineCustom` model**
   - File: `app/models/discipline_custom.rb`
   - Copy `CategoryCustom` content.
   - Rename the class to `DisciplineCustom`.
   - Preserve validations, scopes, and `belongs_to :created_by` association.

3. **Create the new `disciplines` database table**
   - Generate a migration that `create_table :disciplines` with the same schema as the current `categories` table (string `name`, timestamps, etc.).
   - Add the same unique index on `name` and any other constraints.

4. **Seed the `disciplines` table**
   - Since existing data will be ignored, write a simple seed script (or use `rails db:seed`) that inserts the required discipline records (e.g., “Attack”, “Serve”, “Communication”, etc.).

5. **Update `AssessmentCategory` model**
   - Change `belongs_to :category, optional: true` → `belongs_to :discipline, optional: true`.
   - Change `belongs_to :category_custom, optional: true` → `belongs_to :discipline_custom, optional: true`.
   - Update all method references (`custom?`, `source_type`, `label`, etc.) to use the new names.
   - Keep the same validations (`source_is_exactly_one`, `source_must_exist`) – only class names change.

6. **Update `CategoryCustom` model**
   - Rename the file to `discipline_custom.rb`.
   - Rename the class to `DisciplineCustom`.
   - Adjust any references in other files (tests, policies, services).

7. **Update database schema and foreign keys**
   - Create a migration that **renames** the existing `categories` table to `disciplines` (or creates a new table and copies data if you prefer a fresh start).  
   - Update all foreign‑key definitions in `assessment_categories` and any other tables to point to `disciplines` (and `discipline_customs` if that table exists).  
   - Keep the XOR constraint (`category_id IS NOT NULL AND category_custom_id IS NULL …`) – apply it to the new column names.

8. **Update `schema.rb`**
   - Change `create_table "categories"` to `create_table "disciplines"` (and rename columns if needed).  
   - Update all `add_foreign_key` statements that reference `categories` or `category_customs` to the new names.  
   - Rename the `category_customs` table to `discipline_customs` if it exists.

9. **Search & replace all `Category` references**
   - Run a project‑wide search for `Category` (class name, file names, constants, enums, policies, services, UI strings, API payloads, etc.) and replace with `Discipline`.  
   - Do the same for `CategoryCustom` → `DisciplineCustom`.  
   - Pay special attention to:
     - Policy files (`category_policy.rb` → `discipline_policy.rb`).
     - Service objects, concerns, and any custom modules.
     - React/JS assets, component names, prop types, and API payload definitions.

10. **Update tests**
    - Rename test files/classes that inherit from `Category` (e.g., `*_category_test.rb` → `*_discipline_test.rb`).  
    - Adjust factories, stubs, and expectations to use `Discipline` and `DisciplineCustom`.  
    - Ensure migration tests that reference the old table name are updated.

10. **Run the full test suite**
    - After migrations and code changes, run `rails db:migrate` (or your custom migration) and then `bundle exec rspec` (or the appropriate test runner) to verify no regressions.

11. **Seed the new data**
    - Since you want to ignore existing data, truncate/drop the old tables, run the migration, and then run your seeding script/rake task to populate `disciplines` and `discipline_customs`.

12. **Verify UI & API**
    - Deploy to a staging environment, run through all UI screens and API endpoints that previously used “Category” to confirm the new label “Discipline” appears everywhere.  
    - Perform manual smoke tests on key flows (create drill, view assessment, manage categories, etc.) to ensure business logic remains intact.

## Key Considerations
- **XOR Constraint**: The database constraint ensuring exactly one of `category_id` or `category_custom_id` is present must be preserved with the new column names.
- **Foreign Keys & Indexes**: All foreign keys and indexes that reference the old table/column names must be altered to the new names.
- **Tests & Policies**: Update any authorization policies, service objects, and test suites to reference the new names.
- **UI & API**: Update any front‑end component names, API response schemas, and documentation to reflect the new terminology.

---  
*End of plan*