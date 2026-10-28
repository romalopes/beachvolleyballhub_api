## Analysis Domain Models

### 2.1 Analysis Model
Represents a complete analysis with lifecycle states:
- `draft`: Initial state, not yet published
- `published`: Publicly accessible to authorized participants
- `archived`: Final state, no longer active

Key attributes:
- `title`: Analysis title (max 160 characters)
- `summary`: Brief description
- `status`: Current state (draft/published/archived)
- `published_at`: Timestamp when published
- `archived_at`: Timestamp when archived
- `created_by`: User who created the analysis
- `assigned_coach_profile`: Coach assigned to the analysis (optional)
- `organisation`: Organization context (optional)
- `group`: Group context (optional)
- `training_session`: Training session association (optional)
- `tournament`: Tournament association (optional)

### 2.2 AnalysisParticipant Model
Join table between Analysis and PlayerProfile:
- `analysis`: Reference to Analysis
- `player_profile`: Reference to PlayerProfile
- `notes`: Optional notes from participant
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

### 2.3 AnalysisVideo Model
Represents video content for analysis:
- `analysis`: Reference to Analysis
- `video`: Reference to Video (optional, for external videos)
- `source_type`: 'external' or 'upload'
- `title`: Video title
- `description`: Description
- `position`: Ordering position (0-indexed)
- `file`: ActiveStorage attachment (for uploaded videos)
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

### 2.4 AnalysisAnnotation Model
Timestamped annotations on videos:
- `analysis_video`: Reference to AnalysisVideo
- `author`: Reference to User (author)
- `player_profile`: Optional reference to PlayerProfile
- `timestamp_seconds`: Time in seconds from video start
- `body`: Annotation text
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

### 2.5 AnalysisComment Model
Threaded comments on analysis:
- `analysis`: Reference to Analysis
- `author`: Reference to User (author)
- `parent`: Reference to parent comment (for threading)
- `body`: Comment text
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

### 2.6 AnalysisAssessmentSession Model
Join table between Analysis and AssessmentSession:
- `analysis`: Reference to Analysis
- `assessment_session`: Reference to AssessmentSession
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp