"""Org settings, part A: General, Policies, and the Access group."""
from dsl import *

O = "octo-sample-org"
BASE = f"/organizations/{O}/settings"

top = G("o-g-top", "", [
    P("o-general", "General", f"{BASE}/profile", "gear", [
        S("General", [
            T("Organization display name", "", "Octo Sample"),
            T("Email (will be public)", "", "hello@octo.example.invalid"),
            TA("Description", "", placeholder="Add a description"),
            T("URL", "", "https://octo.example.invalid"),
            T("Social accounts", "Link to social profile, up to 4 links"),
            T("Location", "", "Denver, CO"),
            SEL("Billing email (Private)", ["billing@octo.example.invalid"], "Receipts and billing notifications go here."),
            T("Gravatar email (Private)"),
            CB("Display a Sponsor button", "Add a Sponsor button to the organization profile."),
            B("Update profile"),
        ]),
        S("Profile picture", [B("Upload new picture")]),
        S("Terms of Service", [
            I("Standard Terms of Service", "Best for individuals wanting the freedom to move data and independent control of their organization."),
            B("Switch to the GitHub Customer Agreement"),
        ]),
        S("Sponsors update email", [
            T("Sponsors update email (Private)", "The developers and organizations that your organization sponsors can send you updates to this email."),
        ]),
        S("Danger zone", [
            B("Rename organization", "Renaming your organization can have unintended side effects."),
            B("Archive this organization", "Mark this organization and all its repositories as archived and read-only."),
            B("Transfer ownership", "Transfer this organization to another user or to an enterprise."),
            DB("Delete this organization", "Once deleted, it will be gone forever. Please be certain."),
        ], danger=True),
    ]),
    P("o-policies", "Policies", f"{BASE}/policies", "law", [
        S("Policies", [
            I("Organization policies", "Policies set by your enterprise that apply to this organization."),
            L("Enforced policies", ["Repository visibility change · Owners only", "Copilot · Managed by enterprise"]),
            LK("Rulesets", "Organization-wide rulesets for branches and tags."),
        ]),
    ]),
])

access = G("o-g-access", "Access", [
    P("o-billing", "Billing and licensing", f"{BASE}/billing", "credit-card", [
        S("Overview", [
            I("Current metered usage", "Includes usage for GitHub Actions, Codespaces, Packages, Git LFS and Copilot."),
            LK("Usage", "See detailed usage by product, repository and SKU."),
            LK("Budgets and alerts", "Set spending limits and receive alerts."),
            LK("Licensing", "Manage Copilot seats and other licenses."),
        ]),
        S("Plan", [I("GitHub Team", "$4 per user/month"), B("Compare all plans"), DB("Downgrade to Free")]),
        S("Payment information", [
            L("Payment method", ["Visa ending in 4242"]), B("Edit payment method"),
            T("Billing email", "", "billing@octo.example.invalid"), TA("Additional information", "Add your organization's address or VAT number to receipts."),
            L("Payment history", ["2026-09-01 · GitHub Team · $48.00"]),
        ]),
        S("Budgets and alerts", [
            T("Budget amount", "Monthly spending limit for metered products.", "$0"),
            CB("Stop usage when budget limit is reached", "", True),
            CB("Receive budget threshold alerts", "", True),
        ]),
    ]),
    P("o-org-roles", "Organization roles", f"{BASE}/org_role_assignments", "id-badge", [
        S("Role management", [
            L("Pre-defined roles", ["All-repository admin", "All-repository read", "All-repository write", "All-repository triage", "All-repository maintain", "CI/CD admin", "Security manager", "App manager"], "Organization roles grant permissions across the organization and all repositories."),
            B("Create a role"),
        ]),
        S("Role assignments", [
            L("Role assignments", ["@security-team · Security manager", "@octo-ops · CI/CD admin"]),
            B("New role assignment", "Assign an organization role to a user or team."),
        ]),
    ]),
    P("o-repo-roles", "Repository roles", f"{BASE}/roles", "repo", [
        S("Repository roles", [
            L("Pre-defined roles", ["Read", "Triage", "Write", "Maintain", "Admin"], "Repository roles control what people can do in individual repositories."),
            L("Custom roles", ["Security reviewer · inherits Write"]),
            B("Create a role", "Custom repository roles add fine-grained permissions on top of a base role."),
        ]),
    ]),
    P("o-member-privileges", "Member privileges", f"{BASE}/member_privileges", "people", [
        S("Base permissions", [
            SEL("Base permissions", ["No permission", "Read", "Write", "Admin"], "Choose the default permission level for organization members. The base permission will be applied to all repositories in the organization.", "Read"),
        ]),
        S("Repository creation", [
            CB("Public", "Members will be able to create public repositories, visible to anyone.", True),
            CB("Private", "Members will be able to create private repositories, visible to organization members with permission.", True),
        ]),
        S("Repository forking", [
            CB("Allow forking of private repositories", "If enabled, forking is allowed on private and public repositories. If disabled, forking is only allowed on public repositories."),
        ]),
        S("Repository discussions", [
            CB("Allow users with read access to create discussions", "If enabled, all users with read access can create and comment on discussions in repositories of the organization.", True),
        ]),
        S("Projects base permissions", [
            SEL("Projects base permissions", ["No access", "Read", "Write", "Admin"], "Default permission for members on new organization projects.", "Write"),
        ]),
        S("Pages creation", [
            CB("Public", "Members will be able to publish sites with public access control.", True),
            CB("Private", "Members will be able to publish sites with private access control."),
        ]),
        S("Integration access requests", [
            CB("Allow integration requests from outside collaborators", "Outside collaborators will be able to request access for GitHub or OAuth apps to access this organization and its resources."),
        ]),
        S("Admin repository permissions", [
            CB("Allow members to change repository visibilities for this organization", "If enabled, members with admin permissions for a repository will be able to change its visibility. If disabled, only organization owners can change repository visibilities."),
            CB("Allow members to delete or transfer repositories for this organization", "If enabled, members with admin permissions for the repository will be able to delete or transfer public and private repositories. If disabled, only organization owners can delete or transfer repositories."),
            CB("Allow repository administrators to delete issues for this organization", "If enabled, members with admin permissions for the repository will be able to delete issues. If disabled, only organization owners can delete issues."),
            CB("Allow members to see comment author's profile name in private repositories", "If enabled, members with read access to private repositories will be able to see the profile names of comment authors."),
        ]),
        S("Member team permissions", [
            CB("Allow members to create teams", "If enabled, any member of the organization will be able to create new teams. If disabled, only organization owners can create new teams.", True),
        ]),
        S("Team discussions", [
            CB("Enable team discussions for this organization", "Allow members to use team discussions."),
        ]),
        S("App access requests", [
            R("App access requests", ["Members and outside collaborators", "Members only", "Disabled"], "Who can request that owners install GitHub Apps or approve OAuth apps."),
        ]),
        S("Dependency insights", [
            CB("Allow members to view dependency insights", "Members of this organization will be able to view dependency insights.", True),
        ]),
    ]),
    P("o-import-export", "Import/Export", f"{BASE}/import-export", "arrow-switch", [
        S("Mannequins", [
            L("Mannequins", ["mona-imported · from Bitbucket Server"], "Mannequins are placeholder users created when importing repositories. Reclaim them to attribute history to real members."),
            B("Reattribute", "Reclaim a mannequin's contributions for a member."),
        ]),
    ]),
    P("o-moderation", "Moderation", f"{BASE}/blocked_users", "report", [
        S("Blocked users", [
            T("Block a user", "Blocking a user prevents them from interacting with repositories of this organization, such as opening or commenting on issues or pull requests.", placeholder="Search by username, full name or email address"),
            SEL("Block duration", ["For 1 day", "For 3 days", "For 7 days", "For 30 days", "Until it's lifted"]),
            B("Block user"),
            L("Blocked users", ["spam-account-123 · Blocked until lifted"]),
        ]),
        S("Interaction limits", [
            I("Temporary interaction limits", "Temporarily restrict which external users can interact with your repositories (comment, open issues, or create pull requests) for a configurable period of time."),
            R("Limit to existing users", ["Disabled", "Enabled"], "Users that have recently created their account will be unable to interact with the organization's repositories."),
            R("Limit to prior contributors", ["Disabled", "Enabled"], "Users that have not previously committed to the default branch of a repository will be unable to interact with that repository."),
            R("Limit to repository collaborators", ["Disabled", "Enabled"], "Users that are not collaborators of a repository will not be able to interact with that repository."),
            SEL("Enable interaction limits for", ["24 hours", "3 days", "1 week", "1 month", "6 months"]),
        ]),
        S("Code review limits", [
            CB("Limit to users explicitly granted read or higher access", "When enabled, only users explicitly granted access to this organization's repositories will be able to submit pull request reviews that \"approve\" or \"request changes\"."),
        ]),
        S("Moderators", [
            L("Moderators", ["@community-team"], "Moderators can block and unblock users, set interaction limits, and hide comments in public repositories owned by the organization."),
            B("Add a moderator"),
        ]),
    ]),
])
