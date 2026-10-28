## 3. Video Storage and Playback

### 3.1 Video Model Structure
The existing `Video` model stores metadata for external videos:
- `url`: Original video URL
- `title`: Video title
- `description`: Description
- `duration_seconds`: Video duration in seconds
- `provider`: Provider name (YouTube, Vimeo, etc.)
- `external_url`: Normalized provider URL
- `embed_url`: Embeddable URL for the video player

### 3.2 Provider Handling
- Provider-specific URL normalization ensures consistent URL format
- Embed URL generation handles different player requirements per provider
- Validation ensures URLs are from allowed providers
- External video URLs are cached for performance

### 3.3 Active Storage Configuration
ActiveStorage is configured to use Cloudflare R2:
- Custom service definition in `config/storage.yml`:
  ```yaml
  production:
    service: [
      { type: :cloudflare_rd, bucket: ENV["R2_BUCKET"], endpoint: "https://<ACCOUNT_ID>.r2.cloudflarestorage.com", region: "auto", access_key_id: ENV["R2_ACCESS_KEY"], secret_access_key: ENV["R2_SECRET_KEY"] }
    ]
  ```
- Files are stored in a dedicated bucket with proper access controls
- All file access requires authenticated requests

### 3.4 File Type and Size Constraints
- Video uploads limited to 500MB maximum size
- Only video MIME types allowed (video/mp4, video/quicktime, video/webm, etc.)
- Server-side validation in `AnalysisVideo` model ensures only valid video files are accepted
- File type validation occurs during upload and before saving

### 3.5 Security Considerations
- Private access enforced via ActiveStorage's `signed_url` mechanism
- No direct public URLs to uploaded files - all access requires authentication
- File validation prevents malicious uploads
- All file operations require user authentication
- Content-type validation ensures only video files are accepted