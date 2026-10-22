# 01_REPOSITORY_AUDIT.md (continued)

## 4. Existing Assessment Session Models

### 4.1 Core Models
- `AssessmentSession`: Represents a training or assessment session
- `Assessment`: Contains scoring data and results
- `AssessmentDefinition`: Templates for assessment types
- `AssessmentSessionParticipant`: Join table for participants

### 4.2 Authorization Rules
- Creator can manage their own sessions
- Assigned coaches can manage sessions they're part of
- Players can only view sessions they're assigned to
- Admins can manage all sessions

### 4.3 Key Relationships
```ruby
class AssessmentSession < ApplicationRecord
  has_many :assessment_session_participants
  has_many :players, through: :assessment_session_participants
  belongs_to :coach
end
```

## 5. Existing Video and Provider Abstraction

### 5.1 Video Model
- `Video` model stores external video metadata (URL, title, duration)
- Supports multiple providers (YouTube, Vimeo, etc.)
- Normalized provider URLs for consistent access

### 5.2 Provider Handling
- Provider-specific URL normalization
- Embed URL generation for different platforms
- Validation of external video URLs

## 6. Active Storage and Cloudflare R2 Configuration

### 6.1 Storage Configuration
- ActiveStorage configured to use Cloudflare R2
- Custom service definition in `config/storage.yml`:
  ```yaml
  production:
    service: [
      { type: :aliyun,  outpath: "beachvolleyballhub", access_key_id: ENV["ALIYUN_KEY"], secret_access_key: ENV["ALIYUN_SECRET"], region: "auto" },
      { type: :cloudflare_rd, bucket: ENV["R2_BUCKET"], endpoint: "https://<ACCOUNT_ID>.r2.cloudflarestorage.com", region: "auto", access_key_id: ENV["R2_ACCESS_KEY"], secret_access_key: ENV["R2_SECRET_KEY"] }
    ]
  ```

### 6.2 File Type and Size Constraints
- Video uploads limited to 500MB
- Only video MIME types allowed (video/mp4, video/quicktime, etc.)
- Server-side validation in `AnalysisVideo` model

### 6.3 Security Considerations
- Private access enforced via ActiveStorage's `signed_url` mechanism
- No direct public URLs to uploaded files
- All file access requires authenticated requests

## 7. Frontend Routing and Navigation

### 7.1 Main Routes
- `/` - Home
- `/training` - Training sessions
- `/assessments` - Assessment sessions
- `/videos` - Video library
- `/analyses` - Analysis management (new)
- `/hire-analysis` - Coming Soon placeholder

### 7.2 Analysis-Specific Routes
- `/analyses` - List and create
- `/analyses/:id` - View details
- `/analyses/:id/edit` - Edit
- `/hire-analysis` - Placeholder page

### 7.3 Navigation Flow
1. User navigates to `/analyses` 
2. Sees list with filters (status, organization, group)
3. Clicks "Create Analysis" to open form
4. Completes form and submits
5. View created analysis details
6. Optionally link to assessment session
7. Access "Hire Analysis" page (Coming Soon)