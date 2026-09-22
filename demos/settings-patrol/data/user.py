"""GitHub personal account settings (github.com/settings), recreated from the live UI's wording."""
import sys
from dsl import *

U = "octo-sample"

top = G("u-g-top", "", [
    P("u-profile", "Public profile", "/settings/profile", "person", [
        S("Public profile", [
            T("Name", "Your name may appear around GitHub where you contribute or are mentioned. You can remove it at any time.", "Octo Sample"),
            SEL("Public email", ["Select a verified email to display", "octo@example.invalid"],
                "You have set your email address to private. To toggle email privacy, go to email settings and uncheck \"Keep my email address private.\""),
            TA("Bio", "You can @mention other users and organizations to link to them.", placeholder="Tell us a little bit about yourself"),
            T("Pronouns", "", "they/them"),
            T("URL", "", "https://octo.example.invalid"),
            T("Social accounts", "Link to social profile 1, up to 4 links"),
            T("Company", "You can @mention your company's GitHub organization to link it."),
            T("Location", "", "Denver"),
            CB("Display current local time", "Other users will see the time difference from their local time."),
            SEL("Time zone", ["(GMT-07:00) Mountain Time (US & Canada)", "(GMT+00:00) UTC", "(GMT+01:00) Berlin"]),
            B("Update profile"),
        ]),
        S("Profile picture", [B("Edit", "Upload a photo or remove the current profile picture")]),
        S("Contributions & activity", [
            CB("Make profile private and hide activity", "Enabling this will hide your contributions and activity from your GitHub profile and from social features like followers, stars, feeds, leaderboards and releases."),
            CB("Include private contributions on my profile", "Your contribution graph, achievements, and activity overview will show your private contributions without revealing any repository or organization information.", True),
            B("Update preferences"),
        ]),
        S("Profile settings", [
            CB("Show Achievements on my profile", "Your achievements will be shown on your profile.", True),
        ]),
        S("GitHub Developer Program", [
            I("Building an application, service, or tool that integrates with GitHub? Join the GitHub Developer Program, or read more about it at our Developer site."),
            B("Join the GitHub Developer Program"),
        ]),
        S("Jobs profile", [CB("Available for hire", "Show employers you're open to new opportunities.")]),
        S("Trending settings", [CB("Preferred spoken language", "We'll use this language preference to filter the trending repository lists on our Trending Repositories page.")]),
        S("ORCID iD", [B("Connect your ORCID iD", "ORCID provides a persistent identifier - an ORCID iD - that distinguishes you from other researchers.")]),
    ]),
    P("u-account", "Account", "/settings/admin", "gear", [
        S("Change username", [
            I("Changing your username can have unintended side effects."),
            B("Change username", "Changing your username can have unintended side effects. Links to your old profile and repositories will be redirected."),
        ]),
        S("Link Patreon account", [B("Connect with Patreon", "Connect a Patreon account for sponsoring maintainers.")]),
        S("Export account data", [B("Start export", "Export all repositories and profile metadata for @" + U + ". Exports will be available for 7 days.")]),
        S("Successor settings", [
            I("By clicking \"Add Successor\" below, I acknowledge that I am the owner of @" + U + " and am authorizing GitHub to transfer content within that account to my GitHub Successor, designated below, in the event of my death."),
            T("Search by username, full name, or email address", "Designate a successor to manage your repositories if you cannot."),
            B("Add successor"),
        ]),
        S("Delete account", [
            I("Once you delete your account, there is no going back. Please be certain."),
            DB("Delete your account", "Permanently delete your account and all of its data."),
        ], danger=True),
    ]),
    P("u-appearance", "Appearance", "/settings/appearance", "paintbrush", [
        S("Theme preferences", [
            SEL("Theme mode", ["Sync with system", "Single theme"], "Choose how GitHub looks to you. Select a single theme, or sync with your system and automatically switch between day and night themes."),
            R("Day theme", ["Light default", "Light high contrast", "Light Protanopia & Deuteranopia", "Light Tritanopia"], "This theme will be active when your system is set to \"light mode\""),
            R("Night theme", ["Dark default", "Dark high contrast", "Dark Protanopia & Deuteranopia", "Dark Tritanopia", "Dark dimmed"], "This theme will be active when your system is set to \"dark mode\""),
        ]),
        S("Emoji skin tone preference", [
            R("Preferred default emoji skin tone", ["Default", "Light", "Medium-light", "Medium", "Medium-dark", "Dark"]),
        ]),
        S("Tab size preference", [
            SEL("Tab size", ["2", "3", "4", "5", "6", "8", "10", "12"], "Choose the number of spaces a tab is equal to when rendering code", "8"),
        ]),
        S("Markdown editor font preference", [
            CB("Use a fixed-width (monospace) font when editing Markdown", "Font preference for plain text editors that support Markdown styling (e.g. pull request and issue descriptions, comments.)"),
        ]),
    ]),
    P("u-accessibility", "Accessibility", "/settings/accessibility", "accessibility", [
        S("Keyboard shortcuts", [
            CB("Character keys", "Enable GitHub shortcuts that don't use modifier keys in their activation. For example, the g n shortcut to navigate to notifications, or ? to view context relevant shortcuts.", True),
            CB("Command palette", "Modify the shortcuts to trigger the Command Palette for the default search mode and the command mode", True),
        ]),
        S("Motion", [
            R("Autoplay animated images", ["Sync with system", "Enabled", "Disabled"], "Select whether animated images should play automatically."),
        ]),
        S("Content", [
            CB("Link underlines", "Toggle the visibility of underlines on links that are adjacent to text."),
            CB("Hovercards", "Enable previewing link content via mouse hover or keyboard focus before navigation. Move focus to hovercards using the alt + ⬆ keyboard shortcut.", True),
        ]),
        S("Beta features", [
            CB("Use a bottom sheet for dialogs on narrow viewports"),
        ]),
    ]),
    P("u-notifications", "Notifications", "/settings/notifications", "bell", [
        S("Default notifications email", [
            SEL("Default notifications email", ["octo@example.invalid", "octo-sample@users.noreply.github.com"], "Choose which email updates and notifications go to."),
            LK("Custom routing", "You can send notifications to different verified email addresses depending on the organization that owns the repository."),
        ]),
        S("Automatically watch repositories", [
            CB("Automatically watch repositories", "When you're given push access to a repository, automatically receive notifications for it.", True),
            CB("Automatically watch teams", "Anytime you join a new team, you will automatically be subscribed to updates and receive notification when that team is @mentioned.", True),
        ]),
        S("Subscriptions", [
            SEL("Watching", ["On GitHub, Email", "On GitHub", "Email", "Don't notify"], "Notifications for all repositories, teams, or conversations you're watching."),
            SEL("Participating, @mentions and custom", ["On GitHub, Email", "On GitHub", "Email", "Don't notify"], "Notifications for the conversations you are participating in, or if someone cites you with an @mention. Also for all activity when subscribed to specific events."),
            SEL("Customize email updates", ["Reviews", "Pushes", "Comments on Issues and Pull Requests", "Includes your own updates"], "Choose which additional events you'll receive emails for when participating or watching."),
            CB("Ignored repositories", "You'll never be notified."),
        ]),
        S("System", [
            SEL("Actions", ["On GitHub, Email", "On GitHub", "Email", "Don't notify"], "Notifications for workflow runs on repositories set up with GitHub Actions."),
            CB("Only notify for failed workflows", "Send notifications for failed workflows only.", True),
            SEL("Dependabot alerts: New vulnerabilities", ["On GitHub, Email, CLI", "On GitHub", "Email", "Don't notify"], "When you're given access to Dependabot alerts automatically receive notifications when a new vulnerability is found in one of your dependencies."),
            SEL("Dependabot alerts: Email digest", ["Weekly", "Daily", "Off"], "Email a regular summary of Dependabot alerts for up to 10 of your repositories."),
            SEL("Security campaign emails", ["On", "Off"], "Receive email notifications about security campaigns in repositories where you have access to alerts."),
            SEL("Deploy key alert email", ["On", "Off"], "When you are given admin permissions to an organization, automatically receive notifications when a new deploy key is added."),
        ]),
        S("Email notification preferences", [
            CB("Comments on Issues and Pull Requests", "", True),
            CB("Pull Request reviews", "", True),
            CB("Pull Request pushes", "", True),
            CB("Include your own updates", "Receive email for activity you initiated yourself."),
        ]),
        S("Mobile", [
            CB("GitHub Mobile push notifications", "Receive notifications on your phone with the GitHub Mobile app.", True),
        ]),
    ]),
])

access = G("u-g-access", "Access", [
    P("u-billing", "Billing and licensing", "/settings/billing", "credit-card", [
        S("Overview", [
            I("Current metered usage", "Includes usage for GitHub Actions, Codespaces, Packages, Git LFS and Copilot."),
            LK("Usage", "See detailed usage by product, repository and SKU."),
            LK("Budgets and alerts", "Set spending limits and get notified when usage approaches them."),
            LK("Licensing", "Manage Copilot and other seat-based licenses."),
        ]),
        S("Payment information", [
            L("Payment method", ["Visa ending in 4242, expires 08/29"], "The card or PayPal account billed for paid features."),
            B("Edit payment method"),
            T("Billing email", "Receipts are sent to this address.", "octo@example.invalid"),
            TA("Additional information", "Add your name, address, or VAT number to receipts."),
            L("Payment history", ["2026-09-01 · GitHub Pro · $4.00", "2026-08-01 · GitHub Pro · $4.00"]),
        ]),
        S("Current plan", [
            I("GitHub Pro", "Advanced tools for personal accounts."),
            B("Compare all plans"),
            DB("Downgrade to Free", "You will lose access to Pro features at the end of the billing cycle."),
        ]),
        S("Budgets and alerts", [
            T("Budget amount", "Monthly spending limit for metered products.", "$0"),
            CB("Stop usage when budget limit is reached", "", True),
            CB("Receive budget threshold alerts", "Get an email at 75%, 90% and 100% of your budget.", True),
        ]),
    ]),
    P("u-emails", "Emails", "/settings/emails", "mail", [
        S("Emails", [
            L("Email addresses", ["octo@example.invalid — Primary · Visible in emails · Receives notifications"], "Your primary email address will be used for account-related notifications."),
            T("Add email address", "", placeholder="Email address"),
            B("Add"),
        ]),
        S("Primary email address", [
            SEL("Primary email address", ["octo@example.invalid"], "Select an email to be used for account-related notifications and can be used for password reset."),
        ]),
        S("Backup email address", [
            SEL("Backup email address", ["Allow all verified emails", "Only allow primary email"], "Your backup GitHub email address will be used as an additional destination for security-relevant account notifications and can also be used for password resets."),
        ]),
        S("Keep my email addresses private", [
            CB("Keep my email addresses private", "We'll remove your public profile email and use octo-sample@users.noreply.github.com when performing web-based Git operations (e.g. edits and merges) and sending email on your behalf.", True),
            CB("Block command line pushes that expose my email", "When you push to GitHub, we'll check the most recent commit. If the author email on that commit is a private email on your GitHub account, we will block the push and warn you about exposing your private email.", True),
        ]),
        S("Email preferences", [
            R("Email preferences", ["Receive all emails, except those I unsubscribe from.", "Only receive account related emails, and those I subscribe to."], "We'll occasionally contact you with the latest news and happenings from the GitHub Universe."),
            LK("Manage subscriptions", "Unsubscribe from GitHub marketing and research emails."),
        ]),
    ]),
    P("u-security", "Password and authentication", "/settings/security", "shield-lock", [
        S("Change password", [
            T("Old password"), T("New password", "Make sure it's at least 15 characters OR at least 8 characters including a number and a lowercase letter."),
            T("Confirm new password"), B("Update password"), LK("I forgot my password"),
        ]),
        S("Passkeys", [
            I("Passwordless sign-in with passkeys", "Passkeys are webauthn credentials that validate your identity using touch, facial recognition, a device password, or a PIN. They can be used as a password replacement or as a 2FA method."),
            L("Your passkeys", ["MacBook Pro Touch ID · Registered Aug 2, 2026"]),
            B("Add a passkey"),
        ]),
        S("Two-factor authentication", [
            I("Two-factor authentication is enabled", "Two-factor authentication adds an additional layer of security to your account by requiring more than just a password to sign in."),
            L("Preferred 2FA method", ["Authenticator app", "Security keys", "GitHub Mobile", "SMS/Text message"]),
            L("Two-factor methods", ["Authenticator app · Configured", "SMS/Text message · Not configured", "Security keys · 1 key", "GitHub Mobile · 1 device"]),
            B("Edit authenticator app"),
            B("Register new security key"),
            L("Recovery options", ["Recovery codes · Viewed", "Recovery options: GitHub Mobile"], "Recovery codes can be used to access your account in the event you lose access to your device and cannot receive two-factor authentication codes."),
            B("View recovery codes"),
            DB("Disable two-factor authentication"),
        ]),
        S("Sessions", [LK("Web sessions", "This is a list of devices that have logged into your account.")]),
        S("SSH keys", [LK("SSH keys", "Manage SSH keys used to authenticate git over SSH.")]),
    ]),
    P("u-sessions", "Sessions", "/settings/sessions", "broadcast", [
        S("Web sessions", [
            L("Web sessions", ["Denver, CO · Safari on macOS · Your current session", "Chicago, IL · Chrome on Windows · Last accessed 3 days ago"], "This is a list of devices that have logged into your account. Revoke any sessions that you do not recognize."),
            DB("Revoke session", "Sign a device out of your account."),
        ]),
        S("GitHub Mobile sessions", [
            L("GitHub Mobile sessions", ["iPhone · GitHub Mobile · Authentication requests enabled"], "This is a list of devices that have logged into your account via the GitHub Mobile app."),
            DB("Revoke", "Sign the mobile app out."),
        ]),
    ]),
    P("u-keys", "SSH and GPG keys", "/settings/keys", "key", [
        S("SSH keys", [
            L("SSH keys", ["laptop · SHA256:9x7…Qe · Added on Jan 3, 2025 · Last used within the last week · Read/write"], "This is a list of SSH keys associated with your account. Remove any keys that you do not recognize."),
            B("New SSH key", "Add an authentication or signing key."),
            SEL("Key type", ["Authentication Key", "Signing Key"]),
            LK("Check out our guide to connecting to GitHub using SSH keys or troubleshoot common SSH problems."),
        ]),
        S("GPG keys", [
            L("GPG keys", ["Key ID: 3AA5C34371567BD2 · Email: octo@example.invalid · Expires: never"], "This is a list of GPG keys associated with your account. Remove any keys that you do not recognize."),
            B("New GPG key"),
        ]),
        S("Vigilant mode", [
            CB("Flag unsigned commits as unverified", "This will include any commit attributed to your account but not signed with your GPG or S/MIME key. Note that this will include your existing unsigned commits."),
        ]),
    ]),
    P("u-organizations", "Organizations", "/settings/organizations", "organization", [
        S("Organizations", [
            L("Organizations", ["octo-sample-org · Owner", "open-widgets · Member"], "You are a member of these organizations."),
            B("Leave", "Leave an organization you are a member of."),
            B("New organization"),
        ]),
        S("Transform account", [
            I("Transform account into an organization", "You cannot transform this account into an organization until you leave all organizations that you're a member of."),
            B("Turn octo-sample into an organization"),
        ]),
    ]),
    P("u-enterprises", "Enterprises", "/settings/enterprises", "globe", [
        S("Enterprises", [
            I("You are not a member of any enterprises", "Enterprise accounts centrally manage policy and billing for multiple organizations."),
            B("Start a free enterprise trial"),
        ]),
    ]),
    P("u-moderation", "Moderation", "/settings/blocked_users", "report", [
        S("Blocked users", [
            I("Blocking a user prevents the following on all your repositories: opening or commenting on issues or pull requests, starring, forking, or watching, adding or editing wiki pages."),
            T("Block a user", "", placeholder="Search by username, full name or email address"),
            B("Block user"),
            L("Blocked users", ["spam-account-123 · Blocked Mar 4, 2026"]),
            CB("Warn me when a blocked user is a prior contributor to a repository", "On repositories you haven't contributed to yet, we'll warn you and let you decide whether to proceed.", True),
        ]),
        S("Interaction limits", [
            I("Temporary interaction limits for your public repositories", "Temporarily restrict which external users can interact with your repositories (comment, open issues, or create pull requests) for a configurable period of time."),
            R("Limit to existing users", ["Disabled", "Enabled"], "Users that have recently created their account will be unable to interact with your repositories."),
            R("Limit to prior contributors", ["Disabled", "Enabled"], "Users that have not previously committed to the default branch of a repository will be unable to interact with that repository."),
            R("Limit to repository collaborators", ["Disabled", "Enabled"], "Users that are not collaborators of a repository will not be able to interact with that repository."),
            SEL("Enable interaction limits for", ["24 hours", "3 days", "1 week", "1 month", "6 months"]),
        ]),
        S("Code review limits", [
            CB("Limit to users explicitly granted read or higher access", "When enabled, only users explicitly granted access to your repositories will be able to submit pull request reviews that \"approve\" or \"request changes\"."),
        ]),
    ]),
])

code = G("u-g-code", "Code, planning, and automation", [
    P("u-repositories", "Repositories", "/settings/repositories", "repo", [
        S("Repository default branch", [
            T("Default branch name", "Choose the default branch for your new personal repositories. You might want to change the default name due to different workflows, or because your integrations still require \"master\" as the default branch name.", "main"),
            B("Update"),
        ]),
        S("Deleted repositories", [
            L("Deleted repositories", ["octo-sample/old-experiment · Deleted 12 days ago"], "It may take up to an hour for repositories to be displayed here. You can only restore repositories that are not forks, or have not been forked."),
            B("Restore", "Restore a repository deleted in the last 90 days."),
        ]),
    ]),
    P("u-codespaces", "Codespaces", "/settings/codespaces", "codespaces", [
        S("Dotfiles", [
            CB("Automatically install dotfiles", "Codespaces can automatically install your dotfiles into every codespace you create."),
            SEL("Dotfiles repository", ["octo-sample/dotfiles"]),
        ]),
        S("Codespaces secrets", [
            L("Codespaces secrets", ["NPM_TOKEN · Updated 2 months ago · 3 repositories"], "Development environment secrets are environment variables that are encrypted. They are available to any codespace you create using repositories with access to that secret."),
            B("New secret"),
        ]),
        S("GPG verification", [
            R("GPG verification", ["Disabled", "All repositories", "Selected repositories"], "Codespaces created with GPG verification will have GPG capabilities and sign your commits so they are verified."),
        ]),
        S("Settings Sync", [
            R("Settings Sync", ["Disabled", "All repositories", "Selected repositories"], "Enable Settings Sync for codespaces opened in VS Code."),
        ]),
        S("Trusted repositories", [
            R("Trusted repositories", ["Disabled", "All repositories", "Selected repositories"], "Allow codespaces to access other repositories you own when created from these."),
        ]),
        S("Access and security", [
            R("Access and security", ["Disabled", "All repositories", "Selected repositories"], "Codespaces created for a repository can only access that repository. You can allow a codespace for a repository to access other repositories you own."),
        ]),
        S("Editor preference", [
            R("Editor preference", ["Visual Studio Code", "Visual Studio Code for the Web", "JetBrains Gateway", "JupyterLab"], "Choose the default editor for your codespaces."),
        ]),
        S("Default idle timeout", [
            T("Default idle timeout", "A codespace will suspend after a period of inactivity. You can specify a default idle timeout value, which will apply to all codespaces created after the default is changed.", "30 minutes"),
        ]),
        S("Default retention period", [
            T("Default retention period", "Inactive codespaces are automatically deleted 30 days after they have been stopped. You can specify a shorter retention period.", "30 days"),
        ]),
        S("Host image version preference", [
            R("Host image version preference", ["Stable", "Beta"], "The host image defines the operating system and base software a codespace runs on."),
        ]),
        S("Region", [
            R("Region", ["Set automatically", "Set manually"], "Your default region will be used to designate compute resources to your codespaces."),
        ]),
    ]),
    P("u-models", "Models", "/settings/models", "ai-model", [
        S("GitHub Models", [
            TG("Enable GitHub Models", "Use GitHub Models to find and experiment with AI models in the playground and via the API.", True),
            I("Usage", "Free rate-limited usage is included. Opt into paid usage to go beyond the free limits."),
            CB("Opt in to paid usage", "Bill model inference beyond free rate limits to your account."),
        ]),
    ]),
    P("u-packages", "Packages", "/settings/packages", "package", [
        S("Deleted packages", [
            L("Deleted packages", ["ghcr.io/octo-sample/api · Deleted 4 days ago"], "These are packages that have been deleted from your account. You can restore a package deleted within the last 30 days."),
            B("Restore"),
        ]),
        S("Package creation", [
            CB("Public", "Members will be able to create public packages, visible to anyone.", True),
            CB("Private", "Members will be able to create private packages, visible to account members with permission.", True),
        ]),
    ]),
    P("u-copilot", "Copilot", "/settings/copilot", "copilot", [
        S("Copilot", [
            I("GitHub Copilot Pro is active for your account"),
            B("Manage subscription"),
        ]),
        S("Features", [
            SEL("Suggestions matching public code (duplication detection filter)", ["Allowed", "Blocked"], "Copilot can allow or block suggestions matching public code."),
            SEL("Copilot in github.com", ["Enabled", "Disabled"], "You can use Copilot Chat in GitHub.com, Copilot for pull requests and more."),
            SEL("Copilot in the IDE", ["Enabled", "Disabled"]),
            SEL("Copilot Chat in the IDE", ["Enabled", "Disabled"]),
            SEL("Copilot in GitHub Mobile", ["Enabled", "Disabled"]),
            SEL("Copilot in the CLI", ["Enabled", "Disabled"]),
            SEL("Copilot code review", ["Enabled", "Disabled"], "Ask Copilot to review your pull requests."),
            SEL("Automatic Copilot code review", ["Disabled", "Enabled"], "Copilot automatically reviews every pull request you open."),
            SEL("Copilot coding agent", ["Enabled", "Disabled"], "Delegate tasks to Copilot and have it open pull requests."),
            SEL("MCP servers in Copilot", ["Enabled", "Disabled"]),
            SEL("Copilot Spaces", ["Enabled", "Disabled"]),
            SEL("Dashboard entry point", ["Enabled", "Disabled"], "Show Copilot chat on your GitHub dashboard."),
        ]),
        S("Models", [
            SEL("Anthropic Claude in Copilot", ["Enabled", "Disabled"]),
            SEL("Google Gemini in Copilot", ["Enabled", "Disabled"]),
            SEL("OpenAI models in Copilot", ["Enabled", "Disabled"]),
        ]),
        S("Privacy", [
            SEL("Allow GitHub to use my data for product improvements", ["Enabled", "Disabled"], "Allow GitHub, its affiliates and third parties to use my data, including Prompts, Suggestions, and Code Snippets, for product improvements."),
            SEL("Allow GitHub to use my data for AI model training", ["Disabled", "Enabled"]),
        ]),
    ]),
    P("u-pages", "Pages", "/settings/pages", "browser", [
        S("Verified domains", [
            L("Verified domains", ["octo.example.invalid · Verified"], "Verify domains to restrict who can publish GitHub Pages sites to them. Verifying a domain prevents takeover attacks."),
            B("Add a domain"),
        ]),
    ]),
    P("u-replies", "Saved replies", "/settings/replies", "reply", [
        S("Saved replies", [
            L("Saved replies", ["Duplicate issue · Thanks! Closing as a duplicate of #…", "Needs repro · Could you share a minimal reproduction?"], "Saved replies are re-usable text snippets that you can use throughout GitHub comment fields. Saved replies can save you time if you're often typing similar responses."),
            T("Saved reply title"), TA("Add a saved reply"), B("Add saved reply"),
        ]),
    ]),
])

security = G("u-g-security", "Security", [
    P("u-code-security", "Code security", "/settings/security_analysis", "shield-check", [
        S("User", [
            SEL("Push protection for yourself", ["Enabled", "Disabled"], "Block commits that contain supported secrets across all public repositories on GitHub.", "Enabled"),
        ]),
        S("Dependency graph", [
            B("Disable all", "Understand your dependencies."), B("Enable all"),
            CB("Automatically enable for new private repositories"),
        ]),
        S("Dependabot", [
            I("Keep your dependencies secure and up-to-date."),
            SEL("Dependabot alerts", ["Enable all", "Disable all"], "Receive alerts for vulnerabilities that affect your dependencies and manually generate Dependabot pull requests to resolve these vulnerabilities."),
            CB("Automatically enable for new repositories", "", True),
            SEL("Dependabot security updates", ["Enable all", "Disable all"], "Enabling this option will result in Dependabot automatically attempting to open pull requests to resolve every open Dependabot alert with an available patch."),
            CB("Automatically enable for new repositories ", ""),
            SEL("Grouped security updates", ["Enable all", "Disable all"], "Groups all available updates that resolve a Dependabot alert into one pull request (per package manager and directory of requirement manifests)."),
            SEL("Dependabot on Actions runners", ["Enable all", "Disable all"], "Run Dependabot security and version updates on Actions runners."),
        ]),
        S("Private vulnerability reporting", [
            SEL("Private vulnerability reporting", ["Enable all", "Disable all"], "Allow your community to privately report potential security vulnerabilities to maintainers and repository owners."),
        ]),
    ]),
])

integrations = G("u-g-integrations", "Integrations", [
    P("u-applications", "Applications", "/settings/installations", "apps", [
        S("Installed GitHub Apps", [
            L("Installed GitHub Apps", ["Netlify · Configure", "Codecov · Configure"], "GitHub Apps augment and extend your workflows on GitHub with commercially supported tools, and they act with the permissions and repository access you grant them."),
            B("Configure"), DB("Uninstall", "Remove an installed GitHub App from your account."),
        ]),
        S("Authorized GitHub Apps", [
            L("Authorized GitHub Apps", ["GitHub CLI · Last used within the last week", "Visual Studio Code · Last used today"], "You have granted these GitHub Apps permission to act on your behalf."),
            DB("Revoke", "Revoke the app's ability to act on your behalf."),
        ]),
        S("Authorized OAuth Apps", [
            L("Authorized OAuth Apps", ["Travis CI · read:org, repo", "Heroku Dashboard · repo"], "You have granted these applications access to your account."),
            DB("Revoke all", "Revoke access for every OAuth App you've authorized."),
        ]),
    ]),
    P("u-reminders", "Scheduled reminders", "/settings/reminders", "clock", [
        S("Scheduled reminders", [
            I("Scheduled reminders", "Configure real-time alerts and scheduled reminders in Slack for pull requests that need your review."),
            SEL("Organization", ["octo-sample-org", "open-widgets"]),
            B("Configure"),
        ]),
    ]),
])

archives = G("u-g-archives", "Archives", [
    P("u-security-log", "Security log", "/settings/security-log", "log", [
        S("Security log", [
            T("Filter", "Search your security log by action, e.g. action:repo.create, or by country.", placeholder="Filter by action, actor, or country"),
            L("Recent events", ["user.login · from Denver, US · 2 hours ago", "oauth_authorization.create · GitHub CLI · 3 days ago", "two_factor_authentication.recovery_codes_regenerated · 4 weeks ago"], "Your security log records the events that change your account's security."),
            B("Export", "Export your security log as JSON or CSV."),
        ]),
    ]),
    P("u-sponsors-log", "Sponsorship log", "/settings/sponsors-log", "heart", [
        S("Sponsorship log", [
            L("Sponsorship log", ["Sponsored @maintainer-sample · $5/month · Jan 2026"], "A record of your sponsorships, including new sponsorships, tier changes, and cancellations."),
            SEL("Period", ["Last 90 days", "Last 12 months", "All time"]),
        ]),
    ]),
])

developer = G("u-g-developer", "", [
    P("u-developer", "Developer settings", "/settings/apps", "code", [
        S("GitHub Apps", [
            L("GitHub Apps", ["octo-release-bot"], "Want to build something that integrates with and extends GitHub? Register a new GitHub App to get started developing on the GitHub API."),
            B("New GitHub App"),
        ]),
        S("OAuth Apps", [
            L("OAuth Apps", ["octo-sample local dev"], "OAuth Apps registered under your account."),
            B("New OAuth App"),
        ]),
        S("Personal access tokens (fine-grained)", [
            L("Fine-grained tokens", ["deploy-script · Expires Dec 1, 2026 · 1 repository"], "Fine-grained personal access tokens can be scoped to specific repositories and permissions."),
            B("Generate new token"),
            SEL("Expiration", ["7 days", "30 days", "60 days", "90 days", "Custom", "No expiration"], "", "30 days"),
            R("Repository access", ["Public repositories", "All repositories", "Only select repositories"]),
        ]),
        S("Personal access tokens (classic)", [
            L("Tokens (classic)", ["old-ci-token · repo, workflow · Never used · Expires on Oct 1, 2026"], "Tokens you have generated that can be used to access the GitHub API."),
            B("Generate new token (classic)"),
            DB("Delete", "Delete a personal access token (classic)."),
            DB("Revoke all", "Revoke every personal access token (classic) on your account."),
        ]),
    ]),
])

if __name__ == "__main__":
    build("user", "octo-sample", [top, access, code, security, integrations, archives, developer], sys.argv[1])
