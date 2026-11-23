# BeachVolleyballHub --- Hire an Analysis

## Detailed Product & Implementation Specification for Codex

**Status:** Proposed implementation plan\
**Project:** BeachVolleyballHub (BVB)\
**Feature:** Hire an Analysis / Video Analysis Service\
**Currency:** AUD\
**Architecture:** Rails API + React/Vite frontend, responsive web/PWA\
**Implementation approach:** Phased, inspect-first, test-driven, with
existing project patterns reused

-------------------------------------------------------------------------

## Implementation Status

| Phase | Title | Status | Doc |
|-------|-------|--------|-----|
| 00 | Repository reconnaissance & architecture review | ✅ **Done** | [phases/phase-00-repository-reconnaissance.md](phases/phase-00-repository-reconnaissance.md) |
| 01 | Domain model, migrations & request creation | ✅ **Done** | [phases/phase-01-domain-model-and-request-creation.md](phases/phase-01-domain-model-and-request-creation.md) |
| 02 | Public pricing/packages & submission API | ✅ **Done** | [phases/phase-02-pricing-packages-and-submission-api.md](phases/phase-02-pricing-packages-and-submission-api.md) |
| 03 | Admin/Curator review, accept/reject, quote, coach assignment | ✅ **Done** | [phases/phase-03-admin-review-and-assignment.md](phases/phase-03-admin-review-and-assignment.md) |
| 04 | Manual invoice/payment tracking & payment gate | ✅ **Done** | [phases/phase-04-invoicing-and-payment-tracking.md](phases/phase-04-invoicing-and-payment-tracking.md) |
| 05 | Request messaging, guest access, email notifications | ✅ **Done** | [phases/phase-05-messaging-guest-access-email.md](phases/phase-05-messaging-guest-access-email.md) |
| 06 | Notifications bell & event coverage | ✅ **Done** | [phases/phase-06-notifications-bell-and-events.md](phases/phase-06-notifications-bell-and-events.md) |
| 07 | Guest account creation & request claiming | ✅ **Done** | [phases/phase-07-guest-account-claiming.md](phases/phase-07-guest-account-claiming.md) |
| 08 | Coach workspace & analysis production | ✅ **Done** | [phases/phase-08-coach-workspace.md](phases/phase-08-coach-workspace.md) |
| 09 | Assessment & Assessment Session integration | ✅ **Done** | [phases/phase-09-assessment-integration.md](phases/phase-09-assessment-integration.md) |
| 10 | Deliverables, submitter dashboard & guest polish | ✅ **Done** | [phases/phase-10-deliverables-dashboards-polish.md](phases/phase-10-deliverables-dashboards-polish.md) |
| 11 | Final integration, security review, regression, production readiness | ✅ **Done** | [phases/phase-11-final-integration-security-readiness.md](phases/phase-11-final-integration-security-readiness.md) |

**Key Deviations from Original Plan** (detailed in Phase 0 doc):
- Frontend routes: reuse existing `/hire-analysis` placeholder instead of `/analysis/hire`
- Video attachments: follow `AnalysisVideo` pattern (no "attachable concern" exists)
- Test framework: Minitest (API) + Vitest (frontend) — not RSpec
- Frontend delivery: `/my/analysis-requests`, `/analysis-requests/:id` and `/admin/analysis-requests` consume the API; staff/coach notification deep links (`/admin/analysis-requests/:id`, `/coach/analysis-requests/:id`) render the shared detail page instead of a separate workspace
- Workflow actions live on `Api::V1::AnalysisRequestsController` (routes already existed); the admin namespace keeps its own equivalents
- Invoice delivery: PDF generated without a gem (`Invoices::PdfDocument`), emailed via `AnalysisRequestInvoiceEmailJob`; staff ledger at `/settings/invoices` (`GET /api/v1/admin/invoices`)
- Messaging: two-way conversation (authenticated + guest token) with one email per message (`AnalysisRequestMessageEmailJob`) and in-app notifications to the other side; internal messages never leave staff
- Analysis production: an approved request gets a real linked `Analysis` (`start_analysis`); the team edits it in `/analyses/:id/edit`, completion publishes it, and the request detail/guest pages show progress and then the shared result
- API routes: resourceful (`resources :analysis_requests` + `collection { get :mine }` + `namespace :admin`) not `/my/` or `/coach/` prefixes
- Crew recipients: via `AppSetting` (no Support/Finance roles)
- Notifications/Email: extend existing `Publisher`/`WorkflowEvents`/`MailTransport` systems
- Messaging: build fresh `AnalysisRequestMessage` (no Wine Words conversation system in BVB)
- Guest claim: reuse existing `EmailVerificationService` + `claim_invitation` patterns

---

## 1. Objective

Build a complete paid (or complimentary) video-analysis service that
allows beach-volleyball players and visitors to submit videos for review
by the BeachVolleyballHub coaching crew.

The service should support:

-   Guest (not logged in) submissions with name and email.
-   Authenticated submissions using profile identity, without
    re-entering name/email.
-   One or more video uploads and/or supported video URLs.
-   Submission review by Admin/Curator.
-   Accept/reject decisions, with a rejection reason.
-   Pricing packages and configurable pricing.
-   Manual invoicing outside BVB (no integrated checkout in the first
    version).
-   Manual payment tracking.
-   Coach assignment and reassignment.
-   Request-specific messaging between submitter and BVB team.
-   In-app bell notifications for relevant interactions.
-   Email notifications for submission, messages, decisions,
    assignments, payment and completion.
-   Guest access to their request through secure email-based access.
-   Guest account creation and claiming/linking of previous eligible
    submissions after email verification.
-   Coach workspace for assigned requests.
-   Final analysis deliverables (written feedback, annotated video,
    files, etc.).
-   Optional links to existing Assessments and Assessment Sessions.
-   Request status and payment status tracked separately.
-   Secure video storage, authorization, audit history and rate
    limiting.

The feature is a service workflow---not simply a video-upload form. Keep
the request as the central record that connects submission, identity,
videos, workflow, payment, messages, coach, assessment context and
deliverables.

------------------------------------------------------------------------

## 2. Product principles

1.  **Guest-first access:** A user should not be forced to create an
    account before submitting a request.
2.  **Identity continuity:** Guest requests can later be claimed by an
    account only after ownership of the email is verified.
3.  **Explicit approval and pricing:** BVB reviews the scope and
    confirms the price before the user is committed to proceeding.
4.  **Manual payment initially:** No card processor or checkout
    integration in Phase 1. BVB sends an invoice using its chosen
    external process and updates invoice/payment records in BVB.
5.  **Payment before work:** Default rule is that analysis work begins
    after payment is marked received, with a permission-controlled
    exception.
6.  **Separate status dimensions:** Workflow status and payment status
    are independent.
7.  **Scoped permissions:** Submitters see only their requests; coaches
    see assigned requests (unless their role permissions allow more);
    Admin/Curator can manage the full workflow.
8.  **Notifications are durable:** In-app notification and email
    delivery are separate channels. A failure in one must not prevent
    the other.
9.  **Reuse project conventions:** Inspect Wine Words
    submission/conversation/account-claim patterns and BVB existing
    notifications, email jobs, authorization, ActiveStorage, assessment,
    and analysis features before designing new abstractions.
10. **Keep history:** Preserve decisions, status changes, assignment
    changes, messages, invoice changes and delivery history.

------------------------------------------------------------------------

## 3. Scope and non-goals

### In scope

-   Public landing and pricing page for Hire an Analysis.
-   Guest and authenticated request submission.
-   Video uploads and video-link submissions.
-   Request review, acceptance, rejection and coach assignment.
-   Request-specific messages.
-   In-app bell notifications.
-   Email notifications.
-   Guest secure access and email verification.
-   Account creation and guest-request claiming.
-   Manual invoice and payment tracking.
-   Coach work area.
-   Deliverables.
-   Assessment/Assessment Session association.
-   Admin settings for package pricing.
-   Audit history, access control, security, tests and documentation.

### Explicitly out of scope for initial release

-   Stripe, PayPal or another payment gateway.
-   Automatic payment reconciliation.
-   Automatic invoice generation as a legal accounting invoice (unless a
    later phase explicitly selects an existing invoice provider).
-   Automated refunds.
-   Live video calls.
-   Marketplace or coach bidding.
-   Public access to uploaded videos.
-   AI-generated analysis of submitted footage.
-   A new chat system unrelated to the request.
-   Rebuilding the existing BVB notification or account system if
    current implementations can be extended safely.

------------------------------------------------------------------------

## 4. User roles and access

### Submitter (guest)

Can:

-   Submit a request with required name and email.
-   Upload permitted videos or provide supported video links.
-   Describe goals, skills or questions for the analyst.
-   Access their request using a secure email-based access mechanism.
-   Read and send request messages.
-   View request status, accepted price and payment/invoice status as
    appropriate.
-   View final deliverables.
-   Create an account with the submission email and claim eligible
    submissions after verification.

Cannot:

-   See other users' requests.
-   Assign coaches or change workflow/payment states.
-   Access internal notes.
-   Access unassigned or private crew discussions.

### Submitter (authenticated)

Same permissions as a guest, plus:

-   Identity/contact details are sourced from their account/profile;
    they should not need to type them again.
-   Request appears in **My Analysis Requests**.
-   Can access their requests after login.
-   May associate relevant player profile(s) when allowed by existing
    BVB permissions.

### Assigned coach

Can:

-   View assigned request(s).
-   Access authorized submitted video(s).
-   Read the request details and conversation.
-   Message the submitter.
-   Add private/internal notes.
-   Update allowed work statuses.
-   Upload deliverables.
-   Mark the work complete when requirements are met.
-   Link or view related assessment context if permitted.

Cannot by default:

-   Accept/reject requests.
-   Set or override pricing.
-   Assign/reassign coaches.
-   View other coaches' requests.
-   Access internal Admin-only configuration.
-   Delete request history.

### Admin / Curator

Can:

-   View and manage all requests.
-   Review submitted videos and scope.
-   Accept or reject submissions.
-   Require rejection reason.
-   Select package and confirm/customize price.
-   Assign/reassign coaches.
-   Manage status and payment fields.
-   Record invoice details and payment receipt.
-   Override the payment-before-work rule with an audit reason.
-   Add internal notes.
-   Link assessments and sessions.
-   Manage pricing settings (Admin-only if consistent with current
    permission model).
-   View workflow, payment, message and assignment history.

### Crew notification recipients

Use configurable recipients or existing BVB crew/admin notification
mechanisms. Do not hardcode email addresses.

------------------------------------------------------------------------

## 5. Service packages and proposed launch pricing

These are suggested starting prices, not validated market prices. Use
editable settings so the team can adjust pricing without deploying code.

### Suggested packages (AUD)

  ------------------------------------------------------------------------------
  Package              Suggested price Suggested scope      Approx. coach effort
  --------------- -------------------- -------------------- --------------------
  Quick Review                    \$39 One short clip / one           15--20 min
                                       skill / focused      
                                       question; written    
                                       feedback, 3--5       
                                       corrections, drill   
                                       suggestions          

  Standard                        \$69 One match or                   30--40 min
  Analysis                             training video       
                                       within defined       
                                       limits; technical    
                                       and tactical         
                                       feedback; key        
                                       clips/screenshots;   
                                       drills               

  Deep Analysis                  \$109 Longer or multiple             50--65 min
                                       clips within defined 
                                       limits; detailed     
                                       breakdown; annotated 
                                       video; development   
                                       plan                 

  Custom Analysis           From \$149 Full match, multiple               Quoted
                                       videos, partner/team 
                                       analysis,            
                                       competition          
                                       preparation, custom  
                                       scope                
  ------------------------------------------------------------------------------

**Recommended default offering:** Standard Analysis at **\$69 AUD**.

Consider a limited introductory offer, e.g. first 10 Standard analyses
at \$49, only if the crew wants to validate demand and gather feedback.
Avoid permanently underpricing the service.

### Package scope guardrails

Define clear footage limits and expected deliverables for each package
in the settings/content:

-   Quick: short clip, one skill, one question.
-   Standard: a bounded video length or selected sequences; do not imply
    a coach watches an unlimited full match in detail for \$69.
-   Deep: greater scope, annotations and development plan.
-   Custom: Admin/Curator confirms scope, price and expected
    deliverables before acceptance.

The customer pays for coach analysis time and expertise---not simply
video duration.

### Price presentation

Show pricing in:

1.  Public Hire an Analysis landing page before the user submits.
2.  Submission form package selection.
3.  Request detail page, displaying the final accepted/quoted amount.

Include clear language: **"Your final price will be confirmed by BVB
after reviewing your request and before you commit to proceeding."**

Pricing must be configurable, not hardcoded in React or server business
logic.

### Pricing configuration

Implement an Admin settings area using the project's existing settings
pattern, if suitable. Configure:

-   Package key/name.
-   Description.
-   Display price.
-   Currency (AUD for launch).
-   Enabled/disabled.
-   Scope and limits.
-   Display ordering.
-   Optional introductory pricing/campaign (only if scope and design
    support it safely).

Persist a price snapshot on each accepted request. Later package price
changes must not alter previously accepted requests.

------------------------------------------------------------------------

## 6. Submission UX

### Public landing page

Add a clear entry point in the existing Analysis area/navigation, with a
service explanation and CTA such as **Hire an Analysis**.

Landing page content:

-   Explain what video analysis offers.
-   Explain who performs the analysis (BVB crew).
-   Display packages, prices and scope.
-   Explain submission/review/acceptance/invoice/payment/work/delivery
    process.
-   Explain supported videos and link requirements.
-   Explain that acceptance and final price are confirmed by the crew.
-   Provide an accessible submission CTA.
-   Use responsive layout and project design conventions.

### Guest submission form

Required:

-   Name.
-   Email.
-   Package preference (or "Not sure / Custom").
-   At least one video (upload and/or supported URL, depending on
    approved implementation).
-   Description / analysis goals / specific question.
-   Consent/acknowledgement as needed for submitted footage and privacy.

Optional:

-   Player(s) or participant name(s).
-   Skill focus (serve, reception, setting, attack, block, defence,
    transition, tactics, decision-making, other).
-   Additional notes.
-   Preferred contact details, if project supports them.

Guest contact email must be captured as the identity/contact address for
this submission. Use email verification or secure claim mechanisms
before account linkage.

### Authenticated submission

-   Do not ask for name/email again if profile values exist.
-   Use the authenticated user as owner.
-   Allow player profile selection only when the existing
    relationship/permission rules allow it.
-   Same package, video, focus and description fields as guest
    submission.
-   Request is visible under My Analysis Requests immediately after
    creation.

### Video input

Support one or multiple video items. The implementation should assess
feasibility, storage capacity, supported formats and size limits before
finalizing.

Each video may include:

-   Type: upload or URL.
-   Title/label.
-   Optional notes.
-   Order.
-   ActiveStorage attachment for upload.
-   Validated external URL for link submissions.

Security and usability:

-   Validate file extension, MIME/content, size and upload
    authorization.
-   Do not trust the browser-supplied content type alone.
-   Avoid public/predictable file URLs.
-   Make video access permission-checked.
-   Handle upload errors and retry UX.
-   Avoid placing large video files in email.
-   Confirm that external video links are accessible to assigned coaches
    and communicate limitations.

### Initial submission status

Creating a request automatically places it in **Pending Review**. Create
a request reference/number suitable for UI and emails, but never use a
guessable ID as authorization.

### Submission confirmation

After submission:

-   Show request confirmation and reference.
-   Explain that BVB will review it.
-   Explain that the price is not final until confirmed.
-   For guest submitters, explain secure access and email sent.
-   Send crew notification email.
-   Create appropriate in-app notifications for relevant BVB users.

------------------------------------------------------------------------

## 7. Request workflow and statuses

### Workflow status

Suggested statuses:

  Status               Meaning
  -------------------- ------------------------------------------------------
  Submitted            Request successfully created
  Pending Review       Awaiting BVB review
  Accepted             BVB accepts the request and confirms the scope/price
  Rejected             BVB declines the request
  Assigned             Coach has been assigned
  In Progress          Coach has begun analysis
  Awaiting Submitter   Crew needs information or reply
  Completed            Analysis delivered
  Cancelled            Request cancelled

Use the existing application conventions for enums/state machines. Do
not implement an uncontrolled status string if the project has a safer
pattern.

### Suggested transitions

-   Submission → Pending Review (automatic).
-   Pending Review → Accepted or Rejected.
-   Accepted → Assigned (after coach assignment).
-   Assigned → In Progress (after paid/authorized-to-start gate).
-   In Progress → Awaiting Submitter.
-   Awaiting Submitter → In Progress.
-   In Progress → Completed (after deliverable is provided).
-   Eligible states → Cancelled (permissions and policy-defined
    constraints).

Admin/Curator may have appropriate workflow override permissions. Coach
can update only coach-authorized work states. Log all transitions.

### Status history

Record:

-   Previous status.
-   New status.
-   Changed by user (nullable for system events).
-   Timestamp.
-   Comment/reason, where applicable.

### Payment state is separate

Do not combine workflow status and payment status into a single state
machine. A request may be Accepted but Awaiting Invoice, Invoiced but
unpaid, Paid but not yet assigned, etc.

------------------------------------------------------------------------

## 8. Pricing, invoicing and payment (manual, no checkout)

### Payment model

The initial system does **not** process payment. BVB invoices externally
using its existing method. BeachVolleyballHub records invoice/payment
status.

### Proposed payment statuses

  Payment status     Meaning
  ------------------ -------------------------------------------------
  Not Required       Complimentary/free request
  Awaiting Invoice   Accepted; invoice has not been recorded as sent
  Invoiced           Invoice sent; awaiting payment
  Paid               Payment received and confirmed
  Overdue            Invoice overdue
  Cancelled          Invoice/payment obligation cancelled
  Refunded           Payment refunded (if applicable)

Confirm how complimentary requests are represented so they can proceed
without a payment gate.

### Request fields (payment-related)

Candidate fields (finalize based on project conventions):

-   `analysis_package_id` or package key (snapshot/reference).
-   `quoted_amount` / `price_amount` (decimal, never floating point).
-   `currency` (AUD).
-   `payment_status`.
-   `invoice_reference`.
-   `invoice_url` (optional).
-   `invoice_attachment` (optional secure attachment).
-   `invoice_sent_at` / `invoiced_at`.
-   `invoice_due_at` (optional).
-   `paid_at`.
-   `payment_notes` (internal/admin-only).
-   `payment_override` or equivalent authorization marker.
-   `payment_override_by_id`.
-   `payment_override_reason`.
-   `payment_override_at`.

Use secure attachment handling for invoices. If invoice links are
external, validate URL handling and do not expose admin-only invoice
data unintentionally.

### Admin actions

Admin/Curator workflow:

1.  Review request and footage.
2.  Select package or custom scope.
3.  Confirm price.
4.  Accept and communicate price/scope.
5.  Record invoice details when invoice is sent.
6.  Mark payment received when verified.
7.  Assign coach.
8.  Authorize start after payment, unless approved override.
9.  Coach completes analysis.
10. Upload deliverables and mark completed.

Admin should be able to:

-   Change quote before acceptance.
-   Apply custom price or discount.
-   Set complimentary / Not Required payment.
-   Record invoice reference, link or attachment, sent date and due
    date.
-   Mark invoice sent.
-   Mark paid.
-   Mark overdue/cancelled/refunded if needed.
-   Override payment-before-work restriction only with permission and
    reason.
-   View a clear payment history.

### Payment gate

Default: coach cannot start analysis until payment status is Paid or Not
Required.

If Admin/Curator allows work before payment:

-   Require elevated permission.
-   Require a reason.
-   Record who/when.
-   Notify/record the override.
-   Do not silently bypass the gate.

### Submitter view

Show only appropriate customer-facing information:

-   Package and agreed price.
-   Currency.
-   Invoice status.
-   Invoice reference/link/attachment if intended for submitter.
-   Due date.
-   Payment status.
-   Payment instructions (configurable content).
-   Paid confirmation.

Never display internal payment notes, override reasons, or sensitive
invoice details to submitters unless explicitly designated
customer-visible.

### Payment notifications

-   Invoice recorded as sent → notify submitter.
-   Payment marked received → notify submitter (optional) and assigned
    crew/coach as appropriate.
-   Payment overdue → Admin/Curator reminder or notification according
    to policy.
-   Complimentary request → notify submitter of accepted service without
    invoice.

------------------------------------------------------------------------

## 9. Coach assignment and workspace

### Assignment

Admin/Curator can:

-   Assign an eligible coach.
-   Reassign the coach.
-   See coach profile and relevant permissions.
-   Record assignment changes in history.
-   Add private assignment notes.
-   Notify the new coach.
-   Notify submitter that a coach has been assigned, if appropriate.

Only eligible coach profiles/accounts should be selectable. Inspect
BVB's current coach roles/profile relationships first.

### Coach workspace

Provide a coach view for assigned requests, including:

-   Request ID/title.
-   Submitter identity/contact (only as necessary).
-   Package/scope and confirmed price (coach visibility should be
    permission-policy determined; at minimum scope is visible).
-   Status.
-   Submitted videos with secure playback.
-   Submitter description and analysis focus.
-   Assessment links.
-   Conversation.
-   Internal notes.
-   Work status actions.
-   Deliverable upload.

Coach cannot accept/reject, alter pricing, invoice/payment status or
reassign unless their role grants those additional capabilities.

------------------------------------------------------------------------

## 10. Messaging and conversation

### Request-specific messages

Implement a conversation tied to each Analysis Request. Reuse Wine Words
conversation/message patterns where appropriate, but keep BVB ownership,
authorization and notification rules independent and well tested.

Participants:

-   Submitter (guest or logged-in).
-   Assigned coach.
-   Admin/Curator.

Messages should include:

-   Request association.
-   Sender user ID (nullable for guest).
-   Sender display-name snapshot.
-   Sender email snapshot (where needed for guest messages; protect it).
-   Sender role/context.
-   Message body.
-   Timestamp.
-   Read state or existing read-receipt approach.
-   Optional attachment(s) if the existing system supports secure
    attachment handling.

### Internal notes

Do not mix internal notes with public messages. Use a distinct model or
clearly separated message type with strict authorization and tests.
Internal notes must never be visible to the submitter and must not
trigger submitter-facing message emails.

### Guest messages

Guest access must be securely authenticated by email-based request
access. Do not rely on request IDs alone. Consider verified email plus
revocable, expiring access token, secure token rotation and rate-limited
email delivery. If tokenized links are used, store only token hashes
where practical, avoid logging tokens, and provide revocation/expiry.

### Message notifications

For a new message:

-   Create an in-app notification for intended recipients.
-   Send email notification to appropriate recipients.
-   Do not notify the sender about their own message.
-   Avoid duplicate emails to the same recipient.
-   Respect user notification preferences if the app already has them.
-   Email must contain a safe link to the request/conversation.
-   Guest messages and replies must follow the same secure-access
    pattern.
-   Notification delivery failure should not roll back a saved message.

------------------------------------------------------------------------

## 11. In-app notifications (bell)

Reuse BVB's existing notification/bell implementation rather than
creating a parallel notification system.

Create notifications for relevant request interactions.

### Event matrix

  -----------------------------------------------------------------------
  Event                               Notify
  ----------------------------------- -----------------------------------
  New submission                      Admin/Curator/configured crew

  Request accepted                    Submitter

  Request rejected                    Submitter

  Coach assigned                      Assigned coach and submitter (where
                                      appropriate)

  Coach reassigned                    New coach and submitter; previous
                                      coach if policy says

  Status changed                      Relevant submitter, assigned coach
                                      and crew

  New message                         Message recipient(s)

  Additional info requested           Submitter

  Submitter replies                   Assigned coach and crew as
                                      appropriate

  Invoice sent/recorded               Submitter

  Payment received                    Submitter and relevant BVB staff

  Work started                        Submitter (optional event)

  Deliverable uploaded                Submitter

  Analysis completed                  Submitter

  Request cancelled                   Relevant participants

  Internal note added                 Only authorized staff participants,
                                      if notifications are desired
  -----------------------------------------------------------------------

### Notification requirements

-   Durable notification record.
-   Correct recipient.
-   Request reference/title and meaningful event text.
-   Direct link to request.
-   Read/unread state.
-   Mark one as read.
-   Mark all as read.
-   Unread count in bell.
-   Avoid self-notification.
-   Enforce permissions when opening target.
-   Notification creation is independent of email delivery.
-   Avoid duplicates on retry; consider idempotency keys or event
    uniqueness where appropriate.

------------------------------------------------------------------------

## 12. Email notifications

Reuse existing BVB mailers, background jobs, and provider configuration.

### Email events

1.  New submission → crew.
2.  Submission accepted and price/scope confirmed → submitter.
3.  Submission rejected → submitter, with reason.
4.  Coach assigned → coach and submitter (policy-dependent).
5.  Coach reassigned → new coach and relevant participants.
6.  New message → recipient(s).
7.  Invoice sent/recorded → submitter.
8.  Payment confirmed → submitter.
9.  Status change → relevant participants for user-visible transitions.
10. Additional information requested → submitter.
11. Analysis completed → submitter.
12. Deliverable uploaded → submitter.

### Email content

Include:

-   Request reference.
-   Event/subject.
-   Brief relevant summary.
-   Link to request.
-   Secure guest access link when applicable.
-   No video attachments.
-   No internal notes.
-   No confidential details.

### Email implementation requirements

-   Queue delivery using existing background-job architecture.
-   Email failure must not undo the request, message or status
    transition.
-   Avoid duplicate notifications on retries.
-   Use configured BVB crew recipient lists/settings.
-   Respect privacy and avoid exposing other recipients unnecessarily.
-   Test mailer previews and delivery jobs.

------------------------------------------------------------------------

## 13. Guest access, account creation and request claiming

This is a key Wine Words-inspired feature.

### Guest request ownership

Guest submission creates a request with:

-   `user_id` nullable.
-   Submitter name/email snapshot.
-   Secure guest access mechanism.
-   Request remains usable without registration.

Guest should receive a secure link to access the request. The access
mechanism should be:

-   High entropy.
-   Stored securely (token hash if feasible).
-   Revocable.
-   Expiring or renewable under a defined policy.
-   Rate-limited.
-   Not based on predictable request IDs.
-   Not logged in plaintext.
-   Scoped to only the relevant request(s).

### If guest email already belongs to a registered account

-   Do not create a duplicate user.
-   Do not link the guest request solely because the guest typed an
    existing email.
-   Offer/guide them to log in or verify email ownership.
-   After authentication and email verification, allow linking eligible
    requests.
-   Preserve original submitter name/email snapshot.

### If guest email is not registered

-   Guest can still submit and track their request.
-   Offer account creation using the submission email.
-   Verify email before account ownership/claiming.
-   After successful registration and email verification, find eligible
    guest requests matching the verified email and offer or perform safe
    linking, according to the established Wine Words pattern.
-   Do not require registration to continue the service.

### Claiming previous submissions

A registered user can claim guest submissions matching their verified
email.

Claim rules:

-   Email must be verified.
-   Match exact normalized email according to safe normalization rules.
-   Do not claim based on name.
-   Claim only eligible guest records not already associated with
    another user.
-   Preserve request IDs, timestamps, videos, messages, status history,
    invoices, payment records and deliverables.
-   Record a claim/link audit event.
-   Prevent duplicate claiming.
-   Avoid revealing whether an email has an account to unauthenticated
    users in ways that enable enumeration.
-   Use transactional logic for claims to prevent race conditions.

### Account UX

-   Guest request page should show a non-intrusive "Create an account to
    manage your analysis requests in one place" prompt.
-   Existing account email: offer login and verified claiming.
-   New email: create account, verify email, then link eligible
    requests.
-   My Analysis Requests page lists linked requests with status and
    unread-message indicators.

------------------------------------------------------------------------

## 14. Assessment and Assessment Session integration

Analysis Requests may be associated with existing BVB Assessments and
Assessment Sessions.

### Requirements

-   Link an Analysis Request to an existing Assessment, where relevant.
-   Link to one or multiple Assessment Sessions if the data model
    allows.
-   Links are optional; an Analysis Request can exist independently.
-   Linking should not create or modify an Assessment automatically.
-   Respect player, coach, org and assessment permissions.
-   Provide search/select UI for eligible records.
-   Display analysis request link from assessment context, where
    appropriate.
-   Display linked assessment context in request detail.
-   Include completed deliverables in relevant player development views
    only if current product permissions and privacy design support it.

### Relationship design

Inspect the current Assessment/AssessmentSession models and decide the
safest relationship structure.

Do not assume the model is exactly named or has a particular foreign key
before examining code. Consider a join table if a request may be related
to multiple sessions or assessments. Document the chosen relationship
and constraints.

------------------------------------------------------------------------

## 15. Deliverables and completion

### Deliverable types

Support a flexible set of final outputs:

-   Written analysis.
-   PDF report.
-   Annotated screenshots.
-   Annotated video.
-   Video with voiceover.
-   Coaching recommendations.
-   Training/drill plan.
-   Other supported attachments.

### Deliverable fields

Possible fields:

-   Request association.
-   Title.
-   Description.
-   Type/category.
-   Attachment or secure link.
-   Created/uploaded by.
-   Created timestamp.
-   Visibility.
-   Ordering.

Deliverables must be private and permission-controlled. Do not expose
raw public storage URLs.

### Completion rules

-   Coach/admin can mark completed only when a deliverable or
    appropriate completion note exists (confirm exact product policy).
-   Completed status triggers notification and email.
-   Submitter can view/download deliverables.
-   Preserve completion history.
-   Reopening a completed request should require authorized action and
    be logged.

------------------------------------------------------------------------

## 16. Internal notes and audit trail

### Internal notes

Separate from the submitter-facing conversation.

Examples:

-   Scope concerns.
-   Assignment context.
-   Pricing justification.
-   Coach coordination.
-   Payment override rationale.

Only Admin/Curator and authorized assigned coaches may see internal
notes.

### Audit history

Record relevant changes, including:

-   Status transitions.
-   Acceptance/rejection and reasons.
-   Price/package changes and final agreed quote.
-   Invoice sent/changed.
-   Payment status changes.
-   Coach assignment/reassignment.
-   Payment override.
-   Guest submission claim/account linking.
-   Deliverable upload/removal/replacement.
-   Assessment association changes.

History should be readable in the Admin request detail and not
editable/deletable by ordinary participants.

------------------------------------------------------------------------

## 17. Suggested data model (confirm after codebase inspection)

The central record is **AnalysisRequest**. Suggested entities are
illustrative and should be adjusted to existing naming and patterns.

### AnalysisRequest

Candidate attributes:

-   `user_id` (nullable).
-   Submitter name/email snapshot.
-   Request title.
-   Description.
-   Analysis focus / selected skill.
-   Requested package (snapshot/key).
-   Final package/title snapshot.
-   `quoted_amount` (decimal).
-   `currency`.
-   Workflow status.
-   Payment status.
-   Assigned coach relationship.
-   Reviewed/accepted/rejected by.
-   Accepted/rejected timestamps.
-   Rejection reason.
-   Started/completed timestamps.
-   Invoice reference/link/due date/sent timestamp.
-   Paid timestamp.
-   Payment notes (private).
-   Guest-access/claim-related fields or associated secure-access model.
-   Optional player profile relationship (if permitted).
-   Created/updated timestamps.

### AnalysisVideo

-   Request association.
-   Video type (upload/link).
-   ActiveStorage attachment or validated URL.
-   Title/label.
-   Description/notes.
-   Ordering.
-   Metadata needed for playback, within privacy policy.

### AnalysisMessage

-   Request association.
-   Sender user (nullable for guest).
-   Sender name/email snapshot where appropriate.
-   Sender role/context.
-   Body.
-   Read tracking using current conventions.
-   Attachments (only if secure handling is supported).
-   Timestamps.

### AnalysisDeliverable

-   Request association.
-   Title.
-   Type.
-   Description.
-   Attachment or secure URL.
-   Visibility.
-   Position.
-   Uploaded by.
-   Timestamp.

### AnalysisInternalNote

-   Request association.
-   Author.
-   Body.
-   Visibility rules (internal only).
-   Timestamp.

### AnalysisStatusHistory / AnalysisRequestEvent

-   Request association.
-   Event type.
-   Previous/new status (when applicable).
-   Actor (nullable system actor).
-   Details/reason.
-   Timestamp.

### Assignment history

Consider a dedicated assignment history model or event records:

-   Request.
-   Previous coach.
-   New coach.
-   Changed by.
-   Reason.
-   Timestamp.

### Assessment associations

Use join tables or direct associations after inspecting the current
assessment models and determining whether one-to-many or many-to-many is
needed.

### Package/pricing settings

Store packages in existing settings infrastructure or a suitable
database-backed configuration model, rather than constants. Keep price
snapshot on request.

------------------------------------------------------------------------

## 18. Admin/Curator UI

### Request list

Create an Analysis Requests admin/curator area.

Features:

-   List all requests.
-   Search request ID, submitter name/email, title.
-   Filter workflow status.
-   Filter payment status.
-   Filter assigned coach.
-   Filter package.
-   Filter unread messages.
-   Filter unassigned requests.
-   Filter requests awaiting submitter.
-   Sort by submission date, last activity, status, coach, payment
    state.
-   Pagination.
-   Clear indicators for new submissions, unread messages, overdue
    invoice and unassigned work.

Suggested columns:

-   Request reference.
-   Submitted date.
-   Submitter.
-   Title/package.
-   Workflow status.
-   Payment status.
-   Price.
-   Assigned coach.
-   Last activity.
-   Unread indicator.

### Request detail

Sections/tabs or clear grouped layout:

1.  Overview / submitter.
2.  Request description and analysis goals.
3.  Videos.
4.  Review decision and pricing.
5.  Assignment.
6.  Workflow.
7.  Invoice/payment.
8.  Messages.
9.  Internal notes.
10. Assessment links.
11. Deliverables.
12. History/audit.

Actions:

-   Accept.
-   Reject (reason required).
-   Confirm package/price.
-   Custom quote.
-   Assign/reassign coach.
-   Change permitted status.
-   Record invoice sent.
-   Mark paid.
-   Mark overdue/cancelled/refunded as applicable.
-   Complimentary/no payment required.
-   Payment override with permission and reason.
-   Add internal note.
-   Link/unlink Assessment or Session.
-   Upload deliverable.
-   Complete/reopen (authorized).

------------------------------------------------------------------------

## 19. Coach workspace UI

Create a coach-facing list of assigned Analysis Requests.

Filters:

-   Assigned to me.
-   In progress.
-   Awaiting submitter.
-   Completed.
-   Unread messages.

Request detail:

-   Request information.
-   Package/scope.
-   Submitted videos.
-   Analysis focus.
-   Submitter conversation.
-   Internal notes.
-   Assessment context.
-   Work status controls.
-   Deliverable upload.
-   Completion action.

The coach interface should be mobile-friendly so the coach can review
requests from a tablet/phone, but video playback and file handling
should be tested on supported devices.

------------------------------------------------------------------------

## 20. Submitter experience

### My Analysis Requests (authenticated)

List requests with:

-   Reference.
-   Title/package.
-   Workflow status.
-   Payment status.
-   Price.
-   Assigned coach (if visible).
-   Last activity.
-   Unread message indicator.
-   Link to detail.

Detail:

-   Submission information.
-   Videos.
-   Status timeline.
-   Accepted price.
-   Invoice/payment information and instructions.
-   Conversation.
-   Deliverables.
-   Assessment links (only appropriate to user).
-   Account claim/identity information should not be exposed
    unnecessarily.

### Guest request page

Secure access to:

-   Status.
-   Request details.
-   Video list (where policy allows guest viewing).
-   Messages.
-   Price/payment information.
-   Deliverables.
-   Reply form.

Guest access must be token/email-verified or otherwise secure; never
authorize by request number alone.

------------------------------------------------------------------------

## 21. Notification and email event matrix (consolidated)

  -----------------------------------------------------------------------
  Event                   In-app notification     Email
  ----------------------- ----------------------- -----------------------
  New request submitted   Crew/Admin/Curator      Crew configured
                                                  recipients

  Accepted + price        Submitter               Submitter
  confirmed                                       

  Rejected                Submitter               Submitter

  Coach assigned          Coach + submitter as    Coach + submitter
                          appropriate             

  Coach reassigned        New coach, submitter,   Relevant participants
                          optionally prior coach  

  Status update           Relevant participants   Based on notification
                                                  policy

  New message             Recipient(s)            Recipient(s)

  Additional information  Submitter               Submitter
  requested                                       

  Submitter response      Coach and crew as       Relevant crew
                          appropriate             

  Invoice sent            Submitter               Submitter

  Payment received        Submitter; relevant     Submitter (optional),
                          staff                   staff if configured

  Work started            Submitter (optional)    Optional

  Deliverable uploaded    Submitter               Submitter

  Completed               Submitter               Submitter

  Cancelled               Relevant participants   Relevant participants

  Internal note           Authorized staff only   No submitter email
                          if notifications        
                          enabled                 
  -----------------------------------------------------------------------

All notifications should be permission-aware, avoid self-notification,
prevent duplicates where feasible, and link to the correct request.
Notification and email jobs must be independent.

------------------------------------------------------------------------

## 22. Security, privacy and abuse prevention

Because this feature handles player footage and potentially identifying
details, implement security deliberately.

### Authorization

-   Enforce request-level authorization in the Rails API.
-   Guest access is secured by a token or verified identity, not a
    guessable ID.
-   Submitter access is limited to their own request.
-   Coach access is limited to assigned requests unless broader
    permission is explicitly configured.
-   Admin/Curator access follows role/permission checks.
-   Internal notes and payment notes are staff-only.
-   Assessment relationships must not leak information from another
    player/org.

### Videos and files

-   Private storage by default.
-   No predictable public URLs.
-   Authorization on playback/download.
-   File size/type validation.
-   Content validation beyond filename where feasible.
-   Safe external-link validation.
-   Secure attachments for invoices/deliverables.
-   Consider upload rate limits and abuse prevention.
-   Configure retention/deletion policy for declined, cancelled or old
    requests.
-   Do not put videos or sensitive file URLs in email.

### Guest tokens

-   High entropy.
-   Hash at rest when feasible.
-   Expiration and renewal strategy.
-   Revocation.
-   Rate limiting.
-   Avoid token logging.
-   Use secure transport.
-   Scope token to the request.
-   Email verification required before account claim.

### Abuse protection

-   Rate-limit anonymous submissions and messaging.
-   Use Cloudflare Turnstile or the project's existing
    human-verification integration where appropriate.
-   Prevent spam, upload abuse and email flooding.
-   Use idempotency/duplicate protection for submission and notification
    jobs.
-   Avoid account/email enumeration.

### Privacy

-   Explain how submitted videos will be used and who can view them.
-   Confirm submitter has rights/permission to share footage and
    participant images.
-   Avoid broad public sharing by default.
-   Ensure guest and account workflows do not expose email addresses to
    other participants.

------------------------------------------------------------------------

## 23. Phased implementation plan with AI/Codex prompts

**Important execution rule:** Each phase prompt instructs Codex to
inspect the existing repository first, then implement only that phase,
run tests, report results and stop. Do not ask the AI to implement every
phase at once. Run phases sequentially, review the output and
commit/backup between phases.

Before starting, make sure Codex is working in the correct
BeachVolleyballHub repository---not Wine Words.

### Phase 0 --- Repository reconnaissance and architecture review ✅

**Goal:** Understand current BVB implementation and Wine Words reference
patterns before writing code.

**Inspect:**

-   BVB Rails API structure and React frontend.
-   Existing Analysis feature and video storage/playback.
-   Authentication and user/profile/role/permission models.
-   Coach and Curator roles.
-   Notification bell system, notification model and API.
-   Email mailers, background jobs and provider configuration.
-   ActiveStorage configuration and storage provider.
-   Assessments and Assessment Sessions model/relationships/UI.
-   Existing admin/curator UI patterns.
-   PWA/mobile layout patterns.
-   Wine Words submission workflow: guest submission, contact email,
    account linking/claiming, conversations/messages, notifications,
    email jobs.
-   Existing tests, factories/fixtures, test commands and
    lint/type-check commands.

**Deliverables:**

-   Brief architecture map.
-   Existing features/patterns suitable for reuse.
-   Model/relationship recommendation validated against actual schema.
-   Proposed API endpoints and frontend routes.
-   Risks/unknowns, especially video storage and guest access.
-   Phase-by-phase implementation outline adjusted to the codebase.

**AI Prompt:**

> You are working on BeachVolleyballHub. Begin by inspecting the
> repository thoroughly; do not implement code yet. Confirm the
> repository is the BeachVolleyballHub project and summarize the Rails
> API + React/Vite structure. Inspect the existing Analysis feature,
> video uploads/storage, authentication, roles/permissions, coach
> profiles, Curator/Admin workflows, notifications/bell, mailers/jobs,
> ActiveStorage, Assessments and Assessment Sessions. If Wine Words
> source is available in the local workspace, inspect its submission
> workflow specifically for anonymous submissions, email identity,
> account creation/claiming, messages/conversations, notifications and
> emails. Do not assume Wine Words files are present; if unavailable,
> report that limitation and work from BVB patterns. Identify existing
> code that can be reused and avoid duplicating infrastructure. Produce
> an architecture/recommendation report with candidate models,
> associations, routes, permissions, UI areas, tests, risks and a phased
> plan. Do not modify files in this phase.

**Acceptance:** Architecture report is grounded in actual files/models
and no code changes are made.

------------------------------------------------------------------------

### Phase 1 --- Domain model, migrations and request creation ✅

**Goal:** Establish the Analysis Request core and safe
guest/authenticated submission.

Implement:

-   AnalysisRequest core model and validations.
-   Request reference/number if project conventions support it.
-   Guest submission with name/email.
-   Authenticated submission linked to user without asking for identity
    again.
-   Analysis package selection and requested scope.
-   Description/analysis focus.
-   Multiple videos (upload and/or external URL as agreed in Phase 0).
-   Private ActiveStorage handling.
-   Initial status Pending Review.
-   Request API endpoints.
-   Public/authenticated submission forms.
-   Submission confirmation.
-   Crew email and in-app notification integration, using current
    systems where possible.

Keep pricing/payment attributes minimal in this phase if the later phase
owns them, but establish the design so they can be added without
breaking the model. Store identity snapshots for guest requests.

**AI Prompt:**

> Implement Phase 1 of Hire an Analysis in BeachVolleyballHub based on
> the approved Phase 0 architecture report. First inspect the relevant
> files and confirm the exact models, routes, conventions and tests you
> will change. Implement the AnalysisRequest core, guest and
> authenticated submission, identity/contact behavior, package
> preference, request description/analysis focus, video upload and/or
> validated video URL support, and initial Pending Review status. Reuse
> existing authentication, authorization, ActiveStorage, notification
> and mailer/job infrastructure. Guests must not need accounts.
> Authenticated users must not be asked to re-enter their name/email;
> use their account/profile. Validate all inputs and keep videos
> private. Implement the backend API and frontend
> submission/confirmation UX. Do not implement accept/reject, coach
> assignment, invoicing, messaging, guest claiming or final deliverables
> in this phase unless required as a minimal placeholder by the approved
> architecture. Add migrations, model/API/frontend tests, update
> documentation, run the appropriate test and lint/type-check commands.
> Report changed files, migration instructions, test results,
> limitations and stop.

**Acceptance:**

-   Guest can submit a valid request without logging in.
-   Guest name/email required.
-   Logged-in user identity comes from the authenticated profile.
-   Video items validate and are securely stored/accessed.
-   Request starts in Pending Review.
-   Submission confirmation works.
-   Crew receives submission notification/email.
-   Tests pass.

------------------------------------------------------------------------

### Phase 2 --- Public pricing/packages and configurable pricing ✅

**Goal:** Display packages and allow authorized staff to maintain
pricing.

Implement:

-   Pricing configuration using existing settings architecture or a
    database-backed model.
-   Quick Review \$39, Standard \$69, Deep \$109, Custom from \$149 AUD
    as initial defaults.
-   Package descriptions, scope/limits, order, enabled/disabled.
-   Public package/pricing display.
-   Package selection in submission form.
-   Final price snapshot fields on request (if not added already).
-   Admin pricing configuration UI.
-   Tests for configuration and snapshot behavior.

**AI Prompt:**

> Implement Phase 2: configurable Hire an Analysis pricing and public
> package display. Inspect existing BVB settings/admin configuration
> patterns first. Configure initial AUD packages: Quick Review \$39,
> Standard Analysis \$69, Deep Analysis \$109, Custom from \$149. Prices
> and package descriptions/limits must be editable without deployment
> and must not be hardcoded into React or business logic. Show pricing
> on the public Hire an Analysis page and package choices in the form.
> Preserve a package/price snapshot on requests so later price changes
> do not modify historical accepted quotes. Ensure Admin-only pricing
> edits (or the established authorized settings role) and public
> read-only access. Include clear notice that BVB confirms the final
> price after reviewing the request. Implement tests and run relevant
> suite/lint/type checks. Report files, settings format, migrations,
> tests and stop.

**Acceptance:**

-   Public prices visible before submission.
-   Package descriptions and scope are clear.
-   Authorized Admin can change pricing.
-   Historical request prices remain stable.

------------------------------------------------------------------------

### Phase 3 --- Admin/Curator review, accept/reject, quote and coach assignment ✅

**Goal:** Implement the staff workflow.

Implement:

-   Admin/Curator request list, search, filters and pagination.
-   Request detail view.
-   Accept/reject actions.
-   Rejection reason required.
-   Confirm/custom price.
-   Assign/reassign eligible coach.
-   Status transitions.
-   Status history and assignment history.
-   Internal notes.
-   Staff notification events.
-   Authorization tests.

**AI Prompt:**

> Implement Phase 3: Admin/Curator review and coach assignment for
> Analysis Requests. Inspect existing BVB admin/curator list/detail
> patterns and role permissions. Build a request-management list with
> search, status filters, coach filters, package filters and unread
> indicators where supported. Implement detail view with submitter,
> request description, videos, package/scope, quote, status and history.
> Admin/Curator can accept or reject; rejection requires a reason. They
> can confirm the price or create a custom quote, assign/reassign
> eligible coaches, update allowed workflow states and add staff-only
> internal notes. Implement a status transition service or existing
> state pattern and audit/status history. Notify submitter/crew/coaches
> using existing notification/email systems where the event rules are
> already clear; avoid implementing the full message system in this
> phase. Enforce API authorization, not only frontend controls. Add
> tests for happy paths, invalid transitions, unauthorized roles,
> rejection reason, price changes and assignment. Run tests and stop
> with a report.

**Acceptance:**

-   Staff can review requests.
-   Accept/reject and reason are persisted.
-   Price is confirmed and snapshotted.
-   Coach assignment is secure.
-   History records transitions and assignments.
-   Unauthorized users cannot manage requests.

------------------------------------------------------------------------

### Phase 4 --- Manual invoice/payment tracking and payment gate ✅

**Goal:** Track external invoices and payment without integrating
checkout.

Implement:

-   Payment status independent of workflow status.
-   Invoice reference/link/attachment and due date.
-   Invoice sent timestamp.
-   Paid timestamp.
-   Payment notes staff-only.
-   Complimentary/no payment required.
-   Overdue/cancelled/refunded states if appropriate.
-   Admin actions for recording invoice sent and payment received.
-   Submitter-facing invoice/payment status and instructions.
-   Payment gate preventing coach work from starting unless Paid or Not
    Required.
-   Permission-controlled payment override with reason and audit.
-   In-app/email notifications for invoice and payment events.

**AI Prompt:**

> Implement Phase 4: manual invoice and payment tracking for Hire an
> Analysis. There is no online payment gateway. Inspect the current
> request model and authorized staff workflow. Add a separate payment
> status lifecycle (Not Required, Awaiting Invoice, Invoiced, Paid,
> Overdue, Cancelled, Refunded as justified by current needs), invoice
> reference, optional secure invoice URL/attachment, sent/due
> timestamps, paid timestamp and staff-only payment notes. Keep workflow
> status independent from payment status. Staff can record invoice sent
> and mark payment received. Complimentary requests use Not Required.
> Default behavior must prevent a coach from starting analysis until
> Paid or Not Required. Any override must require elevated permission
> and an explicit reason, with actor/time/history. Show only
> customer-safe invoice/payment fields to the submitter. Add
> email/in-app notifications for invoice and payment changes without
> coupling them to the database transaction. Add authorization, state,
> payment gate, override, privacy and notification tests. Run tests and
> stop with a report.

**Acceptance:**

-   Staff can record invoice and payment manually.
-   No payment gateway is added.
-   Submitter sees correct price/invoice/payment state.
-   Coach work is gated by payment by default.
-   Override is permission-controlled and audited.
-   Complimentary analysis works.

------------------------------------------------------------------------

### Phase 5 --- Request-specific messaging, guest access and email notifications ✅

**Goal:** Provide secure communication with the BVB crew.

Implement:

-   AnalysisMessage conversation.
-   Guest secure access to request.
-   Guest token lifecycle (secure storage/hash, expiry/renewal,
    revocation, rate limiting).
-   Logged-in submitter access.
-   Coach/Admin/Curator messaging permissions.
-   Message read states if supported.
-   Internal notes kept separate.
-   Email on new message.
-   In-app notification on new message.
-   Additional-info requested/submitter reply workflows.
-   Email content/links safe for guests and authenticated users.

**AI Prompt:**

> Implement Phase 5: request-specific messaging and secure guest access.
> First inspect Wine Words message/conversation and
> guest-access/account-claim implementation if the repository is
> accessible, and inspect BVB notification/email patterns. Build a
> conversation attached to each AnalysisRequest. Guests must be able to
> read/reply using a secure request-scoped access mechanism; do not
> authorize using a request ID alone. Use high-entropy, revocable,
> expiring tokens, securely stored (hashed where feasible), rate-limit
> access and message/email operations, and avoid logging raw tokens.
> Authenticated users can access only their requests. Assigned coach and
> Admin/Curator can message under permissions. Keep staff-only internal
> notes entirely separate from submitter-visible messages. A saved
> message must not fail because email delivery failed. Create recipient
> notifications and email jobs independently, avoid notifying the
> sender, prevent duplicate recipient emails, and ensure messages/links
> do not expose private videos or internal notes. Add
> guest/authenticated/staff access, token lifecycle, rate-limit,
> notification and email tests. Run tests and stop with a report.

**Acceptance:**

-   Guest securely accesses and replies to request.
-   Logged-in user accesses own requests.
-   Coach/staff can communicate as authorized.
-   Messages persist regardless of email failure.
-   No self-notifications.
-   Internal notes remain private.

------------------------------------------------------------------------

### Phase 6 --- Notifications bell and event coverage ✅

**Goal:** Ensure all relevant interactions create durable in-app
notifications.

Implement or extend existing bell system:

-   Submission → crew.
-   Accept/reject → submitter.
-   Coach assignment/reassignment → coach/submitter as policy.
-   Status change → relevant participants.
-   New message → recipients.
-   Info request/reply → relevant participants.
-   Invoice sent/payment received → relevant participants.
-   Deliverable upload/completion → submitter.
-   Cancel → relevant participants.
-   Read/unread state.
-   Mark individual/all read.
-   Unread count.
-   Direct request links.
-   Idempotency/deduplication for event retries.

**AI Prompt:**

> Implement Phase 6: complete in-app bell notifications for Analysis
> Request events. Reuse BVB's existing notification infrastructure.
> Review current event/notification code first and identify the smallest
> safe extension. Cover submission, accept/reject, coach
> assignment/reassignment, relevant status changes, messages,
> information requests/replies, invoice sent, payment received,
> deliverables, completion and cancellation. Notifications should be
> durable, permission-aware, link to the request, include meaningful
> text/reference, support read/unread, mark-one-read, mark-all-read and
> unread count. Do not notify users about their own actions. Avoid
> duplicate notifications on retries and ensure notification creation is
> independent of email delivery. Internal-note notifications, if any,
> are staff-only. Add event/recipient/read-state/idempotency and
> authorization tests. Run tests and stop with a report.

**Acceptance:**

-   Correct recipient gets notification for each required event.
-   Bell/unread count behaves correctly.
-   Notifications navigate to the request.
-   Self-notification and duplicates are prevented.
-   Access is checked on destination.

------------------------------------------------------------------------

### Phase 7 --- Guest account creation and request claiming ✅

**Goal:** Let anonymous submitters register and retain access to past
submissions.

Implement:

-   Existing-email account flow: login, verify and claim without
    duplicate account.
-   New-email account creation.
-   Email verification.
-   Claiming eligible guest requests.
-   My Analysis Requests.
-   Request linking audit history.
-   Secure matching and transactional claim.
-   Account-creation prompts in guest request UI.
-   Privacy protections against account/email enumeration.

**AI Prompt:**

> Implement Phase 7: account creation and claiming guest Analysis
> Requests, inspired by the Wine Words workflow. Inspect the existing
> BVB account-registration/email-verification process and Wine Words
> claim flow if accessible; reuse established patterns instead of
> inventing a second identity system. Guest submissions remain valid
> without an account. A guest can create an account using the submission
> email, verify the email, and claim all eligible guest requests whose
> normalized email matches the verified address. If that email already
> has an account, do not create a duplicate: guide the submitter through
> login and verified claim. Never link solely because someone typed an
> email. Claims must be transactional, prevent race conditions and
> unauthorized claims, preserve original submitter name/email snapshots
> and all request data (videos, messages, history, invoices, payment
> status, deliverables), and record an audit event. Avoid email/account
> enumeration in public responses. Implement My Analysis Requests with
> request status, payment status, price, last activity and unread
> indicators. Add tests for existing account, new account, unverified
> email, multiple guest requests, mismatched email, already-linked
> requests, race/duplicate claim and data preservation. Run tests and
> stop with a report.

**Acceptance:**

-   Guest can continue without registration.
-   New user can create account and verify email.
-   Existing user can login without duplicate account.
-   Only verified matching email can claim.
-   Multiple eligible requests can be claimed.
-   Data and history preserved.
-   User sees requests under My Analysis Requests.

------------------------------------------------------------------------

### Phase 8 --- Coach workspace and analysis production ✅

**Goal:** Deliver a practical work area for coaches.

Implement:

-   Assigned request list.
-   Filters by work status/unread.
-   Secure video playback.
-   Request details and scope.
-   Messages.
-   Internal notes.
-   Work status transitions.
-   Deliverable upload/manage.
-   Complete analysis action.
-   Reopen workflow with authorization/history if required.

**AI Prompt:**

> Implement Phase 8: coach workspace and analysis deliverables. Inspect
> existing BVB coach dashboards and current video/Analysis functionality
> first. Coaches see only requests assigned to them unless role
> permissions explicitly allow broader access. Build a coach list with
> assigned, in-progress, awaiting-submitter and completed filters.
> Detail page includes request scope, videos, submitter instructions,
> authorized assessment context, conversation and internal notes. Coach
> can update permitted statuses, ask for information, upload final
> deliverables (written analysis, PDF, annotated clips/video,
> drills/development plan or other supported file types) and mark
> completed. Coaches cannot accept/reject, change prices/payment, assign
> coaches or access other requests unless explicitly permitted. Secure
> files and playback. Completion should require an appropriate
> deliverable or completion note based on policy. Notify submitter on
> delivery/completion. Add authorization, upload, state transition and
> deliverable tests; run tests and stop with report.

**Acceptance:**

-   Coach sees assigned work only.
-   Coach can review submitted video.
-   Coach can message and update allowed statuses.
-   Coach can upload deliverables and complete request.
-   Submitter is notified.
-   Unauthorized coach actions fail at API level.

------------------------------------------------------------------------

### Phase 9 --- Assessment and Assessment Session integration ✅

**Goal:** Connect video analysis to existing player development
assessments.

Implement:

-   Optional Assessment association.
-   Optional one/multiple Assessment Session associations.
-   Admin/Curator link UI.
-   Permission-aware selectors.
-   Request detail context.
-   Relevant assessment/player views links if suitable.
-   Do not auto-create or change assessments.

**AI Prompt:**

> Implement Phase 9: link Analysis Requests to existing Assessments and
> Assessment Sessions. First inspect the actual current model names,
> associations, org/player access rules and UI. Choose the relationship
> structure based on whether a request can link to multiple
> assessments/sessions; document the decision. Associations are optional
> and must not cause a request to require an assessment. Linking must
> not create or alter an assessment/session. Admin/Curator can
> link/unlink records only when authorized; coaches and submitters see
> only permitted context. Show linked records in the request detail and
> add navigational links where useful. Do not leak another player/org's
> assessment data. Add relationship validation, permission and UI tests.
> Run tests and stop with report.

**Acceptance:**

-   Request can exist without assessment.
-   Links to existing records are supported.
-   Relationships respect permissions and are navigable.
-   Linking does not mutate assessment data.

------------------------------------------------------------------------

### Phase 10 --- Deliverables, submitter dashboard and guest polish ✅

**Goal:** Finish submitter-facing experience.

Implement or polish:

-   My Analysis Requests list and detail.
-   Guest request detail.
-   Status timeline.
-   Accepted quote.
-   Invoice/payment status and safe instructions.
-   Messages.
-   Deliverables.
-   Assessment links (when authorized).
-   Unread message indicators.
-   Guest-to-account prompts.
-   Responsive mobile UX.
-   Accessibility, loading/empty/error states.

**AI Prompt:**

> Implement Phase 10: final submitter experience for Hire an Analysis.
> Review existing user account pages and PWA/mobile styling. Ensure
> authenticated users have My Analysis Requests with status, payment
> state, agreed price, assigned coach (if customer-visible), last
> activity and unread indicators. Request detail should include
> submitted information, videos (securely), status history, accepted
> package/price, customer-safe invoice/payment information,
> conversation, deliverables and assessment links when authorized. Guest
> detail should expose the same customer-safe information through secure
> guest access. Include clear account-creation/claim prompt without
> forcing registration. Ensure mobile responsiveness, accessibility,
> loading, empty and error states. Add UI tests for guest/authenticated
> views and permission boundaries, run lint/type checks and relevant
> test suite, then stop with a report.

**Acceptance:**

-   Guest and registered users have usable request detail.
-   Authenticated list and unread indicators work.
-   Customer-safe invoice/payment data is visible.
-   Deliverables are accessible securely.
-   Mobile experience is usable.

------------------------------------------------------------------------

### Phase 11 --- Final integration, security review, regression and production readiness ✅

**Goal:** Verify end-to-end workflow and prepare deployment.

Run:

-   Full backend tests.
-   Frontend tests.
-   Lint/type checks.
-   Migration checks.
-   Authorization review.
-   Video/file access review.
-   Guest-token review.
-   Email preview/delivery checks.
-   Notification event matrix validation.
-   Account claim review.
-   Payment gate review.
-   Mobile/PWA smoke tests.
-   Performance review of upload/playback.
-   Documentation review.
-   Staging smoke test.
-   Rollback/migration notes.

**AI Prompt:**

> Implement Phase 11: final integration and production-readiness review
> of Hire an Analysis. Do not begin with code changes. Audit the entire
> implemented feature against this specification and inspect actual code
> paths. Produce a checklist covering authorization (guest, submitter,
> coach, curator, admin), private video/files, token handling, email
> notifications, bell notifications, duplicate event delivery, account
> claiming, price snapshots, manual invoice/payment states,
> payment-before-work gate and override, assessment association
> permissions, internal note privacy, deliverable security, validation,
> abuse/rate limits, accessibility, responsive UI and tests. Fix
> confirmed defects in scope, but do not expand into unrelated
> refactors. Run the full available backend and frontend test suites,
> lint/type checks, migrations in a safe test environment and smoke
> tests. Report any tests that cannot run and why. Produce a deployment
> checklist, migration/backout notes, configuration/env requirements,
> known limitations and final acceptance matrix. Stop after the report.

**Acceptance:**

-   All critical tests pass or failures are documented.
-   No unresolved high-risk authorization/privacy issue.
-   Migration/deployment steps are documented.
-   End-to-end workflows tested.
-   Known limitations listed.

------------------------------------------------------------------------

## 24. Notification and email test matrix

Use automated tests for at least these cases:

  -----------------------------------------------------------------------
  Scenario                            Expected result
  ----------------------------------- -----------------------------------
  Guest submits                       Request created; crew notification
                                      and email queued

  Authenticated user submits          Request owned by user; identity
                                      fields auto-filled

  Guest submitter sends message       Crew recipients notified by bell
                                      and email

  Coach sends message                 Submitter notified by bell and
                                      email

  Sender sends message                Sender does not receive own
                                      notification

  Request accepted                    Submitter notification/email
                                      includes agreed price

  Request rejected                    Submitter receives reason

  Coach assigned                      Coach notified; submitter
                                      notification according to policy

  Invoice sent                        Submitter notified; status Invoiced

  Payment marked paid                 Payment state Paid; notification
                                      generated

  Coach starts unpaid request         Blocked unless Not Required/Paid or
                                      authorized override

  Deliverable uploaded                Submitter notified

  Request completed                   Submitter notified

  Guest registers                     Email verification required

  Guest claims request                Only verified matching requests
                                      linked

  Guest tries to claim mismatched     Rejected
  email                               

  User tries another request          Access denied

  Unassigned coach tries request      Access denied unless authorized

  Internal note                       Submitter cannot view; no submitter
                                      email

  Email job fails                     Request/message/notification
                                      remains saved

  Notification job retries            No duplicate notification

  Package price changes               Existing quote remains unchanged
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 25. API design (candidate; confirm conventions)

Do not blindly implement these exact paths. Align with current API
versioning, REST conventions and frontend service patterns.

Potential endpoints:

### Public/authenticated submission

-   `POST /api/v1/analysis_requests`
-   `GET /api/v1/analysis_packages`

### Guest access

-   Guest access exchange/verification endpoint (token-based, secure).
-   Guest message creation endpoint scoped to authorized request.
-   Token refresh/revocation endpoints as designed.

### Submitter

-   `GET /api/v1/my/analysis_requests`
-   `GET /api/v1/analysis_requests/:id`
-   `POST /api/v1/analysis_requests/:id/messages`

### Admin/Curator

-   `GET /api/v1/admin/analysis_requests`
-   `GET /api/v1/admin/analysis_requests/:id`
-   Accept/reject actions.
-   Price quote action.
-   Assign/reassign coach action.
-   Invoice/payment actions.
-   Status transition action.
-   Internal notes.
-   Assessment associations.
-   Deliverable management.

### Coach

-   `GET /api/v1/coach/analysis_requests`
-   Coach request detail.
-   Allowed status action.
-   Message action.
-   Deliverable upload/completion.

Use existing BVB route namespace and authorization patterns. Avoid
introducing redundant endpoints if existing request APIs can be
extended.

------------------------------------------------------------------------

## 26. Frontend route and navigation design (candidate)

Confirm the current navigation structure before implementing.

Potential pages:

-   `/analysis` --- existing Analysis entry page, add Hire an Analysis
    service entry.
-   `/analysis/hire` --- public service/pricing page.
-   `/analysis/hire/submit` --- submission form.
-   `/my/analysis-requests` --- authenticated user list.
-   `/my/analysis-requests/:id` --- authenticated detail.
-   Guest secure route for request access (avoid exposing token in
    persistent logs; use safe exchange/redirect approach).
-   Admin/Curator list/detail routes.
-   Coach assigned-request list/detail routes.

Use existing route conventions, not necessarily these literal paths.

------------------------------------------------------------------------

## 27. Operational configuration

Before deployment, confirm:

-   Crew notification recipient configuration.
-   Email sender/reply-to.
-   Background job worker availability and production behavior.
-   ActiveStorage provider and private access strategy.
-   Video size/type limits.
-   Guest token expiry policy.
-   Rate-limit configuration.
-   Turnstile/human verification settings for public form.
-   Package pricing configuration and default data.
-   Invoice/payment instructions text.
-   Retention policy.
-   Assessment permissions.
-   PWA/mobile upload/playback behavior.
-   Logs do not expose tokens, private URLs or sensitive message
    content.

Do not assume that background jobs run merely because they are enqueued.
Verify production job processing and email delivery configuration.

------------------------------------------------------------------------

## 28. Suggested release strategy

### MVP (recommended first release)

Deliver these first:

-   Public pricing and submission.
-   Guest/authenticated submitter.
-   Video upload/link.
-   Admin review and accept/reject.
-   Price confirmation.
-   Coach assignment.
-   Manual invoice/payment tracking.
-   Request messaging.
-   Crew/submitter email notifications.
-   Bell notifications.
-   Coach analysis and deliverable.
-   Guest secure access.
-   Basic account claim.
-   Basic Assessment/Session links.

### Post-MVP improvements (only if needed)

-   Advanced pricing campaigns/discount codes.
-   Automated overdue invoice reminders.
-   Bulk operations.
-   Analytics dashboard for analysis revenue, turnaround time and coach
    workload.
-   Service-level target/estimated turnaround.
-   Advanced guest token recovery.
-   Multiple coaches collaborating on one analysis.
-   Customer feedback/rating after completion.
-   Recurring analysis packages or subscriptions.
-   Integrated invoicing/payment provider (future decision).

------------------------------------------------------------------------

## 29. Final acceptance checklist

### Submission and identity

-   [ ] Public Hire an Analysis entry and pricing page.
-   [ ] Guest submits with name/email.
-   [ ] Authenticated submitter does not re-enter identity.
-   [ ] Request supports multiple video items.
-   [ ] Video upload/link validation.
-   [ ] Guest can remain unregistered.
-   [ ] Submission confirmation and request reference.

### Review and assignment

-   [ ] Admin/Curator list and detail.
-   [ ] Accept/reject.
-   [ ] Rejection reason required.
-   [ ] Final price confirmed.
-   [ ] Coach assign/reassign.
-   [ ] Status and assignment history.
-   [ ] Internal notes private.

### Pricing and payment

-   [ ] Package pricing configurable.
-   [ ] Launch packages seeded: \$39, \$69, \$109, custom from \$149
    AUD.
-   [ ] Price displayed publicly and during submission.
-   [ ] Quote snapshot saved.
-   [ ] Manual invoice details recorded.
-   [ ] Payment status tracked separately.
-   [ ] Complimentary requests supported.
-   [ ] Paid/Not Required gate.
-   [ ] Authorized override with reason/audit.
-   [ ] Submitter sees safe invoice/payment details.

### Messaging and notifications

-   [ ] Request conversation.
-   [ ] Guest secure access.
-   [ ] Authenticated access.
-   [ ] Coach/staff permissions.
-   [ ] Email on message.
-   [ ] Bell notification on message.
-   [ ] Submission/status/assignment/payment/completion notifications.
-   [ ] Read/unread and mark-all-read.
-   [ ] No self-notifications.
-   [ ] No duplicate notifications on retry.
-   [ ] Email failure does not undo saved activity.

### Guest account conversion

-   [ ] Guest account creation prompt.
-   [ ] Existing-account login path.
-   [ ] New account email verification.
-   [ ] Verified email claim.
-   [ ] Multiple matching guest requests can be claimed.
-   [ ] Preserve data and history.
-   [ ] Prevent email enumeration and unauthorized claims.

### Coach and deliverables

-   [ ] Coach sees assigned requests only.
-   [ ] Secure video playback.
-   [ ] Status updates.
-   [ ] Request messaging.
-   [ ] Internal notes.
-   [ ] Deliverable upload.
-   [ ] Completion action.
-   [ ] Submitter notification.

### Assessment integration

-   [ ] Optional Assessment link.
-   [ ] Optional Assessment Session links.
-   [ ] Permission-safe selectors.
-   [ ] Request/assessment navigation.
-   [ ] No automatic assessment mutation.

### Security and release

-   [ ] Request-level API authorization.
-   [ ] Private videos and files.
-   [ ] Secure guest tokens.
-   [ ] Upload validation.
-   [ ] Rate limiting and human verification.
-   [ ] Privacy/consent wording.
-   [ ] Full test suite.
-   [ ] Frontend lint/type checks.
-   [ ] Mobile/PWA smoke tests.
-   [ ] Deployment/rollback notes.

------------------------------------------------------------------------

## 30. Suggested implementation discipline for Codex

For each phase:

1.  Make sure the correct repository/worktree is open.
2.  Read the phase prompt and the master specification.
3.  Ask Codex to inspect and list intended changes before coding if the
    task has significant uncertainty.
4.  Keep the implementation confined to the phase.
5.  Review migrations and authorization changes manually.
6.  Run the tests before accepting the phase.
7.  Inspect the diff for unrelated changes.
8.  Commit or checkpoint after a stable phase.
9.  Record any deviations from this specification.
10. Continue to the next phase only after the prior phase is accepted.

Do not let Codex silently skip tests or claim success without showing
the commands and results. If a test cannot run, it should say why and
provide the next best validation.

------------------------------------------------------------------------

## 31. Final product vision

**Hire an Analysis** should become a complete BVB coaching service
inside BeachVolleyballHub:

-   Players can submit footage without registration friction.
-   BVB can control acceptance, scope, pricing and assignment.
-   The service can generate revenue while allowing
    complimentary/promotional analyses.
-   Coaches have a focused workspace to do the work.
-   Submitters can communicate with the crew.
-   Guest users can later create accounts without losing their history.
-   In-app notifications and email keep participants informed.
-   Final analysis becomes part of a player's broader development
    context through Assessments and Assessment Sessions.
-   Manual invoicing and payment allow the service to launch without
    payment-gateway complexity.
-   The architecture leaves room for future online payments, coach
    collaboration, analytics and additional service packages without
    requiring a redesign.

**Recommended starting commercial model:** Quick Review \$39 AUD,
Standard Analysis \$69 AUD, Deep Analysis \$109 AUD, Custom from \$149
AUD---editable in Admin and subject to BVB confirmation.

**Recommended build approach:** Start with Phase 0 reconnaissance, then
execute Phases 1--11 sequentially, using each AI prompt as a bounded
task with tests and a completion report.
