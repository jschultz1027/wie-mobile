/// Centralized help text for tap / long-press tooltips across the mobile app.
class HelpContent {
  HelpContent._();

  // ─── Navigation & chrome ───────────────────────────────────────────────

  static const menuButton =
      'Opens the main navigation menu. From here you can reach every portal, tool, and support option based on your role (client, contractor, or admin).';

  static const refreshButton =
      'Reloads the latest data from the server. The icon spins while loading. Use this after making changes elsewhere or when information looks stale.';

  static const logout =
      'Signs you out of the app on this device. You will need your email and password to log in again.';

  static const home =
      'Returns to the home dashboard with system status, feature overview, and quick links to key WIE capabilities.';

  static const toolsSection =
      'Role-based operational tools for monitoring weather, property risk, dispatch, and account management. Items shown depend on whether you are a client, contractor, or admin.';

  // ─── Drawer menu items ─────────────────────────────────────────────────

  static const winterHazard =
      'Real-time winter risk monitoring for your properties. View hazard scores, forecasts, and protection status to decide when service is needed.';

  static const propertyDashboard =
      'Client dashboard showing live risk scores, peak 24h/48h forecasts, and protection status for each property you manage.';

  static const clientPortal =
      'View property zones on a map, check protection status, review alerts, and track completed services — read-only for clients.';

  static const historicalRisk =
      'Look up past risk scores by date or range. Useful for disputes, insurance documentation, and verifying service decisions.';

  static const paymentsBilling =
      'View invoices, payment history, and saved payment methods for your Snow Removal Expert account.';

  static const serviceReports =
      'Browse completed service visits with dates, work performed, and report details for your properties.';

  static const snowRemovalContract =
      'View your active snow removal contract terms, coverage, account manager contact, and emergency line.';

  static const tryDemo =
      'Admin-only interactive demo that generates a sample property report to showcase WIE capabilities.';

  static const completePipeline =
      'Admin demo walking through the full WIE pipeline: weather ingestion, hazard scoring, dispatch, and reporting.';

  static const zoneManager =
      'Admin tool to define and edit property zones on map images. Zones drive per-area risk and dispatch targeting.';

  static const multiPropertyMonitor =
      'Monitor live weather snapshots across all properties at once — compare temperatures and data quality site-by-site.';

  static const contractorManagement =
      'Admin view of all contractors: tiers, compliance, availability, and performance metrics.';

  static const dispatchIntelligence =
      'Run the dispatch engine for a property, review AI recommendations, health checks, and decision history.';

  static const dispatchQueue =
      'Admin queue of pending dispatches. Assign or unassign contractors and filter by urgency, bucket, and work type.';

  static const availabilityCalendar =
      'Admin calendar showing contractor availability blocks across your team for scheduling and capacity planning.';

  static const myShifts =
      'Contractor shift hub: start/end shifts, view assigned properties, and open dispatch details for active work.';

  static const myAvailability =
      'Set when you are available for dispatches. Block vacation, limited hours, or mark full availability on the calendar.';

  static const shiftHistory =
      'Review past shifts, hours worked, and earnings history for your contractor account.';

  static const myEquipment =
      'Register trucks, plows, salt spreaders, and other equipment tied to your contractor profile for dispatch matching.';

  static const myLevel =
      'Your contractor tier, progress toward the next level, and how tier affects dispatch priority and pay.';

  static const getVerified =
      'Upload documents and references required for contractor verification and tier advancement.';

  static const contractorPayments =
      'View earnings statements, payout history, and payment-related support information for contractors.';

  static const weatherAggregator =
      'Live blended weather from multiple sources at a reference location — air temp, soil temp, precipitation, and confidence.';

  static const weatherForecast =
      'Hour-by-hour forecast including freeze-risk windows — useful for planning salt and plow operations.';

  static const supportTicket =
      'Submit billing, service, or app issues and track open requests. For emergencies use the 24/7 phone line in the banner.';

  static const termsPrivacy =
      'Legal terms of use and privacy policy for the Winter Intelligence Engine app operated by Snow Removal Expert Ltd.';

  // ─── Auth screens ──────────────────────────────────────────────────────

  static const loginEmail =
      'The email address registered with your WIE account. Must match the address used during sign-up and email verification.';

  static const loginPassword =
      'Your account password (minimum 6 characters). Passwords are stored securely and never displayed in plain text.';

  static const loginForgotPassword =
      'Request a 6-digit reset code sent to your email. Use the code on the next screen to set a new password.';

  static const loginSignIn =
      'Authenticates your credentials and opens your role-based home screen (client, contractor, or admin portal).';

  static const loginSignUp =
      'Create a new WIE account. You will receive a 6-digit email verification code before you can log in.';

  static const loginLogo =
      'Winter Intelligence Engine — predictive snow and ice monitoring for commercial property management.';

  static const registerFullName =
      'Your display name shown in the app and on service communications.';

  static const registerEmail =
      'A valid email used for login, verification codes, and important service notifications.';

  static const registerPassword =
      'Choose a secure password (at least 6 characters). You will use this with your email to sign in.';

  static const registerRole =
      'Account type: Client (property owner), Contractor (field worker), or other roles as enabled by your organization.';

  static const registerSubmit =
      'Creates your account and sends a 6-digit verification email. You must verify before logging in.';

  static const forgotPasswordEmail =
      'Enter the email on your account. If it exists, a 6-digit reset code will be generated (valid 15 minutes).';

  static const forgotPasswordSubmit =
      'Sends a password reset code. You will be taken to the reset screen to enter the code and new password.';

  static const resetPasswordCode =
      'The 6-digit code from your email. Codes expire after 15 minutes; request a new one if needed.';

  static const resetPasswordNew =
      'Your new password (minimum 6 characters). After resetting you can sign in immediately.';

  static const resetPasswordResend =
      'Request a fresh 6-digit code if the previous one expired or was not received.';

  // ─── Home screen ───────────────────────────────────────────────────────

  static const homeHero =
      'Rotating overview of WIE capabilities: real-time monitoring, zone management, and smart dispatch.';

  static const homeSystemStatus =
      'Live health check of the WIE backend API — confirms the platform is reachable and responding.';

  static const homeFeatures =
      'Quick summary of core modules available in your account based on your role.';

  static const supportSubmit =
      'Sends your request to the support team. You can track status under My Tickets. Attachments will be supported in a future update.';

  static const supportCategory =
      'Choose the type of issue so it is routed to the right team: service, billing, technical, contract, or general questions.';

  static const supportPriority =
      'How urgently you need a response. Use Urgent only for critical service failures — for life-safety emergencies call the 24/7 line.';

  static const supportSubject =
      'A short summary of your issue (shown in your ticket list).';

  static const supportProperty =
      'Optionally link this ticket to a specific property so support has location context.';

  static const supportDescription =
      'Describe the issue in detail: dates, locations, invoice numbers, or steps to reproduce app problems.';

  static const supportContactBanner =
      'Direct contact options for immediate help. Use the 24/7 emergency line during active storm events — tickets are for follow-up requests.';

  // ─── Screen-level overviews (AppBar help button) ───────────────────────

  static const screenHome = '''
Home dashboard for the Winter Intelligence Engine.

• Hero banner — overview of platform capabilities
• System status — API connectivity and health
• Feature cards — shortcuts to tools available for your role

Open the menu (☰) to navigate to portals and tools. Tap ℹ icons on any element for more detail.''';

  static const screenLogin = '''
Sign in to your WIE account.

• Email — your registered address
• Password — your account password
• Forgot password — reset via 6-digit email code
• Sign up — register a new account

Tap any label or ℹ icon for field-specific help.''';

  static const screenRegister = '''
Create a new Winter Intelligence Engine account.

After registering you must verify your email with a 6-digit code before logging in. Tap ℹ icons for help on each field.''';

  static const screenForgotPassword = '''
Request a password reset code.

Enter your account email to receive a 6-digit code (valid 15 minutes). Then complete reset on the next screen.''';

  static const screenResetPassword = '''
Complete your password reset.

Enter the 6-digit code from your email and choose a new password. Use Resend if the code expired.''';

  static const screenWinterHazard = '''
Winter Hazard Monitor — real-time risk for your properties.

• Property selector — choose which site to monitor
• Hazard score & forecast — current and upcoming risk
• Charts — trend over time
• Refresh (↻) — reload latest hazard data

Long-press or tap ℹ on controls for more detail.''';

  static const screenPropertyDashboard = '''
Property Dashboard — client safety overview.

• Property list — all sites with live risk scores
• Detail view — metrics, zones, protection status
• Contact Support — open a support ticket

Tap a property for full detail. Use ℹ icons throughout for explanations.''';

  static const screenClientPortal = '''
Client Portal — zones, protection, and services.

• Property selector — switch between your sites
• Map & zones — visual layout and status table
• Alerts & services — recent activity

Clients have read-only access; contact admin for zone changes.''';

  static const screenHistoricalRisk = '''
Historical Risk Scores — audit and dispute support.

Query daily summaries or date ranges. Export-friendly view of past hazard scores for documentation.''';

  static const screenPaymentsBilling = '''
Payments & Billing — invoices and payment methods.

• Summary cards — total paid and pending
• Invoices tab — billing history
• Payment methods — cards on file''';

  static const screenServiceReports = '''
Past Service Reports — completed visit history.

Filter by property or date. Each report summarizes work performed during a service event.''';

  static const screenSnowRemovalContract = '''
Your Snow Removal Contract — terms and contacts.

Review coverage, account manager details, and the 24/7 emergency line for storm events.''';

  static const screenSupportTicket = '''
Support Center — submit and track requests.

• New Ticket — describe billing, service, or app issues
• My Tickets — status of open and past requests
• Emergency banner — call 24/7 line for urgent storm needs

Tap ℹ on form fields for guidance. Attachments coming soon.''';

  static const screenMyShifts = '''
My Shifts — contractor dispatch hub.

• Start/End shift — clock in for active work periods
• Assignments — properties needing service
• Refresh — pull latest dispatches

Open a dispatch for GPS navigation, zone checklist, and photo upload.''';

  static const screenMyAvailability = '''
My Availability — tell dispatch when you can work.

Add blocks for available, limited, or unavailable time. Dispatch uses this to match you to jobs.''';

  static const screenShiftHistory = '''
Shift History — past work and earnings.

Review completed shifts, duration, and payout-related summaries.''';

  static const screenMyEquipment = '''
My Equipment — fleet registered to your profile.

Add trucks, plows, and spreaders so dispatch knows your capabilities when assigning jobs.''';

  static const screenMyLevel = '''
My Level — contractor tier and advancement.

Tiers affect dispatch priority, site access, and payout rates. Complete jobs and verification to advance.''';

  static const screenGetVerified = '''
Get Verified — upload compliance documents.

Submit ID, insurance, references, and training certificates required for higher tiers and priority dispatch.''';

  static const screenContractorPayments = '''
Contractor Payments — earnings and statements.

View payout history, pending amounts, and billing support contacts.''';

  static const screenContractorPortal = '''
Contractor Portal — your assigned dispatch queue.

Filter by urgency window, sort by risk or name, and accept or review property assignments.''';

  static const screenDispatchDetail = '''
Dispatch Detail — work order for one property.

• Zone checklist — mark zones complete with optional photos
• GPS — navigate to site
• Status updates — progress through the job lifecycle''';

  static const screenTryDemo = '''
Try Demo — admin sample property report.

Generates a demonstration report showing WIE analysis output. For sales and training only.''';

  static const screenCompletePipeline = '''
Complete Pipeline Demo — end-to-end WIE walkthrough.

Admin tool demonstrating weather → hazard → dispatch → reporting flow.''';

  static const screenZoneManager = '''
Zone Manager — define property risk zones.

Select a property, upload or view its map, draw zones, and set attributes that drive scoring and dispatch.''';

  static const screenZoneDetail = '''
Zone Manager Detail — zones for one property.

Edit zone polygons, attributes, and map image. Changes affect hazard and dispatch targeting.''';

  static const screenZoneEdit = '''
Zone Editor — draw or adjust a zone boundary.

Tap to place points on the property map. Finish when the polygon has at least three points.''';

  static const screenDrawZone = '''
Draw Zone — create a new zone polygon on the property image.

Tap to add corner points. Use Finish when the shape is complete.''';

  static const screenMultiProperty = '''
Multi-Property Monitor — weather across all sites.

Compare live temperature and data quality for every property in one view. Refresh reloads snapshots.''';

  static const screenContractorManagement = '''
Contractor Management — admin roster and compliance.

Search and filter contractors by tier, availability, and compliance status. Open a profile for details.''';

  static const screenDispatchIntelligence = '''
Dispatch Intelligence — AI dispatch engine.

Select a property, check engine health, run dispatch, and review recommendations and history.''';

  static const screenDispatchQueue = '''
Dispatch Queue — assign contractors to pending jobs.

Filter by bucket and work type. Assign or unassign contractors from the queue cards.''';

  static const screenAvailabilityCalendar = '''
Availability Calendar — team schedule overview.

Filter contractors and view availability blocks on a calendar. Refresh updates latest schedules.''';

  static const screenWeatherAggregator = '''
Weather Aggregator — multi-source live weather.

Blended air/soil temperature, precipitation, and source confidence for a reference location. Auto-refreshes periodically.''';

  static const screenWeatherForecast = '''
Weather Forecast — hourly predictions.

See upcoming hours, min/max temps, and freeze-risk periods for operational planning.''';

  static const screenTermsPrivacy = '''
Terms & Privacy — legal policies.

Terms of use and privacy policy for the Winter Intelligence Engine app. Contact info for Snow Removal Expert Ltd.''';

  static const screenVideoPlayer = '''
Training Video — contractor verification or onboarding content.

Use playback controls to watch required or optional training material.''';
}
