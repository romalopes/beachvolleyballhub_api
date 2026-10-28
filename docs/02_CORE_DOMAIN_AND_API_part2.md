## API Contracts

### 2.1 AnalysisController
Endpoints:
- `GET /api/v1/analyses`: List analyses with filtering
- `GET /api/v1/analyses/:id`: Show analysis details
- `POST /api/v1/analyses`: Create new analysis
- `PATCH /api/v1/analyses/:id`: Update analysis
- `POST /api/v1/analyses/:id/publish`: Publish analysis
- `POST /api/v1/analyses/:id/archive`: Archive analysis
- `POST /api/v1/analyses/:id/link_assessment_session`: Link assessment session
- `DELETE /api/v1/analyses/:id/assessment_sessions/:assessment_session_id`: Unlink assessment session

### 2.2 AnalysisVideoController
Endpoints:
- `POST /api/v1/analyses/:analysis_id/analysis_videos`: Create video (upload or external)
- `DELETE /api/v1/analysis_videos/:id`: Delete video

### 2.3 AnalysisAnnotationController
Endpoints:
- `POST /api/v1/analysis_videos/:analysis_video_id/annotations`: Create annotation
- `PATCH /api/v1/analysis_annotations/:id`: Update annotation
- `DELETE /api/v1/analysis_annotations/:id`: Delete annotation

### 2.4 AnalysisCommentController
Endpoints:
- `POST /api/v1/analyses/:analysis_id/comments`: Create comment
- `DELETE /api/v1/analysis_comments/:id`: Delete comment

## API Response Structure

### 2.1 Analysis Response
```json
{
  "id": 123,
  "title": "Q3 Training Analysis",
  "summary": "Quarterly training assessment",
  "status": "published",
  "published_at": "2023-09-15T10:30:00Z",
  "created_at": "2023-09-10T09:00:00Z",
  "updated_at": "2023-09-15T10:30:00Z",
  "can_manage": true,
  "can_delete": false,
  "can_comment": true,
  "created_by": {
    "id": 456,
    "name": "John Doe"
  },
  "assigned_coach_profile": {
    "id": 789,
    "name": "Jane Smith"
  },
  "organisation": {
    "id": 101,
    "name": "Beach Volleyball Club"
  },
  "group": {
    "id": 202,
    "name": "Youth Division"
  },
  "training_session": {
    "id": 303,
    "title": "Summer Training Camp"
  },
  "tournament": {
    "id": 404,
    "name": "Regional Championship"
  },
  "participants": [
    {
      "id": 505,
      "player_profile_id": 606,
      "name": "Alex Johnson",
      "notes": "Excellent performance"
    }
  ],
  "video_count": 5
}
```

### 2.2 AnalysisVideo Response
```json
{
  "id": 789,
  "source_type": "upload",
  "title": "Training Session 3",
  "description": "Detailed breakdown of session 3",
  "position": 2,
  "playback_url": "https://r2.example.com/beachvolleyballhub/analysis_videos/abc123.mp4",
  "external_url": null,
  "can_embed": false,
  "duration_seconds": 1800,
  "can_manage": true
}
```

### 2.3 AnalysisAnnotation Response
```json
{
  "id": 1234,
  "timestamp_seconds": 900,
  "body": "Good technique on the serve",
  "author": {
    "id": 505,
    "name": "John Doe"
  },
  "player_profile": {
    "id": 606,
    "name": "Alex Johnson"
  },
  "created_at": "2023-09-15T10:30:00Z"
}
```

## Authorization Rules

### 2.1 AnalysisPolicy
- `view?`: User can view the analysis if they are creator, assigned coach, or participant in published analysis
- `manage?`: User can manage if they are creator, assigned coach, or admin
- `create?`: Only users with permission to create analyses
- `publish?`: User must be creator or assigned coach
- `archive?`: User must be creator or assigned coach
- `destroy?`: Only creator or admin can delete (draft only)
- `comment?`: User must be creator, assigned coach, or have permission to comment

### 2.2 Key Authorization Checks
- Creator can manage their own analyses
- Assigned coach can manage analyses they're assigned to
- Players can only view published analyses they participate in
- Admins have full access to all analyses
- No user can access analyses outside their authorized scope