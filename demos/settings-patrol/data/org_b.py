"""Org settings, part B: Code, planning, and automation."""
from dsl import *
from org_a import BASE

RUNNERS = ["All repositories", "Selected repositories", "Disabled"]

code = G("o-g-code", "Code, planning, and automation", [
    P("o-repo-general", "Repository · General", f"{BASE}/repository-defaults", "repo", [
        S("Repository default branch", [
            T("Default branch name", "Choose the default branch for new repositories in this organization. You might want to change the default name due to different workflows, or because your integrations still require \"master\" as the default branch name.", "main"),
            B("Update"),
        ]),
        S("Repository labels", [
            L("Default labels", ["bug", "documentation", "duplicate", "enhancement", "good first issue", "help wanted"], "Default labels applied to new repositories."),
            B("New label"),
        ]),
        S("Commit signoff", [
            R("Require contributors to sign off on web-based commits", ["Disabled", "All repositories", "Allow repositories to choose"], "Choose whether repositories will require contributors to sign off on commits they make through GitHub's web interface. Signing off is a way for contributors to affirm that their commit complies with the repository's terms, commonly the Developer Certificate of Origin (DCO)."),
        ]),
    ]),
    P("o-rulesets", "Repository · Rulesets", f"{BASE}/rules", "checklist", [
        S("Rulesets", [
            L("Rulesets", ["protect-main · Active · 12 repositories · Branch", "release-tags · Evaluate · Tag"], "Rulesets define whether collaborators can delete or force push and set requirements for any pushes, such as passing status checks or a linear commit history."),
            B("New branch ruleset"), B("New tag ruleset"), B("New push ruleset", "Block pushes by file path, extension, or size across repositories."),
            SEL("Enforcement status", ["Active", "Evaluate", "Disabled"]),
            CB("Restrict deletions", "Only allow users with bypass permissions to delete matching refs.", True),
            CB("Block force pushes", "Prevent users with push access from force pushing to refs.", True),
            CB("Require a pull request before merging", "Require all commits be made to a non-target branch and submitted via a pull request before they can be merged."),
            CB("Require status checks to pass", "Choose which status checks must pass before the ref is updated."),
            CB("Require signed commits", "Commits pushed to matching refs must have verified signatures."),
            CB("Require linear history", "Prevent merge commits from being pushed to matching refs."),
            L("Bypass list", ["Organization admin · Always"], "Exempt roles, teams, or apps from this ruleset."),
        ]),
    ]),
    P("o-custom-properties", "Repository · Custom properties", f"{BASE}/custom-properties", "checklist", [
        S("Custom properties", [
            L("Properties", ["team · single select", "data_sensitivity · single select"], "Custom properties allow you to decorate your repositories with information such as compliance frameworks, data sensitivity, or project details."),
            B("New property"),
            CB("Allow repository actors to set this property", "Repository admins can set the property's value."),
        ]),
    ]),
    P("o-topics", "Repository · Topics", f"{BASE}/topics", "checklist", [
        S("Topics", [
            T("Suggested topics", "Topics suggested to repository admins in this organization.", "internal, service, library"),
        ]),
    ]),
    P("o-codespaces", "Codespaces", f"{BASE}/codespaces", "codespaces", [
        S("Codespaces access", [
            R("Codespaces access", ["Disabled", "Enable for specific members or teams", "Enable for all members", "Enable for all members and outside collaborators"], "Allow members to use Codespaces billed to the organization."),
        ]),
        S("Codespace ownership", [
            R("Codespace ownership", ["Organization ownership", "User ownership"], "Choose who pays for codespaces created from this organization's repositories."),
        ]),
        S("Policies", [
            B("Create Policy", "Restrict machine types, idle timeouts, retention periods, base images and port visibility for codespaces."),
            SEL("Maximum idle timeout", ["30 minutes", "60 minutes", "240 minutes"]),
            SEL("Port visibility", ["Private", "Organization", "Public"], "Restrict whether forwarded ports can be public."),
        ]),
    ]),
    P("o-planning", "Planning", f"{BASE}/planning", "project", [
        S("Issue types", [
            L("Issue types", ["Task", "Bug", "Feature"], "Issue types classify and manage different types of issues across the organization."),
            B("Create new type"),
        ]),
        S("Issue fields", [L("Issue fields", ["Priority · single select"], "Custom fields added to issues across the organization.")]),
    ]),
    P("o-projects", "Projects", f"{BASE}/projects", "project", [
        S("Projects", [
            CB("Enable projects for the organization", "Allow members to create projects in this organization.", True),
            CB("Allow members to change project visibilities for this organization", "Members with admin permissions can change project visibility."),
        ]),
    ]),
    P("o-copilot", "Copilot · Policies", f"{BASE}/copilot/policies", "copilot", [
        S("Access", [
            R("Copilot access", ["Disabled", "Enabled for all members", "Enabled for selected members"], "Choose who in your organization can use Copilot. Seats are billed per user."),
            L("Seat assignments", ["@octo-sample · Last active today"]),
        ]),
        S("Features", [
            SEL("Suggestions matching public code", ["Blocked", "Allowed"], "Copilot can allow or block suggestions matching public code."),
            SEL("Copilot in github.com", ["Enabled", "Disabled"]),
            SEL("Copilot in the IDE", ["Enabled", "Disabled"]),
            SEL("Copilot code review", ["Enabled", "Disabled"]),
            SEL("Copilot coding agent", ["Disabled", "Enabled"], "Let Copilot work on assigned issues and open pull requests in the organization's repositories."),
            SEL("MCP servers in Copilot", ["Disabled", "Enabled"]),
            SEL("Copilot Extensions", ["Disabled", "Enabled"]),
            SEL("Preview features", ["Disabled", "Enabled"]),
        ]),
        S("Models", [
            SEL("Anthropic Claude in Copilot", ["Enabled", "Disabled"]),
            SEL("Google Gemini in Copilot", ["Disabled", "Enabled"]),
        ]),
        S("Content exclusion", [
            TA("Repositories and paths to exclude", "Copilot will not use or suggest content from excluded files."),
        ]),
    ]),
    P("o-actions-general", "Actions · General", f"{BASE}/actions", "play", [
        S("Policies", [
            R("Actions permissions", ["Allow all actions and reusable workflows", "Allow octo-sample-org actions and reusable workflows", "Allow octo-sample-org, and select non-octo-sample-org, actions and reusable workflows", "Disable actions"], "Choose which repositories are permitted to use GitHub Actions and which actions they may run."),
            SEL("Enabled repositories", RUNNERS),
            CB("Require actions to be pinned to a full-length commit SHA"),
        ]),
        S("Artifact and log retention", [
            T("Artifact and log retention", "Choose the repository settings default for artifact and log retention. You can set a value from 1 to 90 days for public repositories.", "90 days"),
        ]),
        S("Fork pull request workflows from outside collaborators", [
            R("Approval for running fork pull request workflows from contributors", ["Require approval for first-time contributors who are new to GitHub", "Require approval for first-time contributors", "Require approval for all external contributors"], "Choose which subset of outside collaborators will require approval to run workflows on their pull requests."),
        ]),
        S("Fork pull request workflows in private repositories", [
            CB("Run workflows from fork pull requests", "This tells Actions to run workflows from pull requests originating from repository forks."),
            CB("Send write tokens to workflows from fork pull requests", "This tells Actions to send a GITHUB_TOKEN with write permissions to workflows from pull requests originating from repository forks."),
            CB("Send secrets and variables to workflows from fork pull requests", "This tells Actions to send repository secrets and variables to workflows from pull requests originating from repository forks."),
            CB("Require approval for fork pull request workflows", "Workflows from fork pull requests will require approval from someone with write access."),
        ]),
        S("Workflow permissions", [
            R("Workflow permissions", ["Read and write permissions", "Read repository contents and packages permissions"], "Choose the default permissions granted to the GITHUB_TOKEN when running workflows in this organization.", "Read repository contents and packages permissions"),
            CB("Allow GitHub Actions to create and approve pull requests", "This controls whether GitHub Actions can create pull requests or submit approving pull request reviews."),
        ]),
    ]),
    P("o-actions-runners", "Actions · Runners", f"{BASE}/actions/runners", "server", [
        S("Runners", [
            L("Runners", ["ubuntu-latest-4-cores · GitHub-hosted · Idle", "build-mac-01 · Self-hosted · macOS · Active"], "Host your own runners and customize the environment used to run jobs in your GitHub Actions workflows."),
            B("New runner", "Add a new self-hosted or larger GitHub-hosted runner."),
            DB("Remove runner"),
        ]),
    ]),
    P("o-actions-runner-groups", "Actions · Runner groups", f"{BASE}/actions/runner-groups", "server", [
        S("Runner groups", [
            L("Runner groups", ["Default · All repositories", "release · 2 repositories"], "Runner groups control which repositories and workflows can use a set of runners."),
            B("New runner group"),
            CB("Allow public repositories", "Runners in this group can be used by public repositories. Running workflows from forks of public repositories on self-hosted runners is risky."),
        ]),
    ]),
    P("o-models", "Models", f"{BASE}/models", "ai-model", [
        S("GitHub Models", [
            TG("Enable GitHub Models", "Allow members to use GitHub Models in repositories owned by this organization.", True),
            R("Models allowed", ["All publishers", "Only selected models"]),
        ]),
    ]),
    P("o-webhooks", "Webhooks", f"{BASE}/hooks", "webhook", [
        S("Webhooks", [
            L("Webhooks", ["https://ci.octo.example.invalid/github (push, pull_request) · Last delivery succeeded"], "Webhooks allow external services to be notified when certain events happen. When the specified events happen, we'll send a POST request to each of the URLs you provide."),
            B("Add webhook"),
            T("Payload URL", "", placeholder="https://example.com/postreceive"),
            SEL("Content type", ["application/x-www-form-urlencoded", "application/json"]),
            T("Secret", "Used to sign payloads so you can verify deliveries came from GitHub."),
            R("Which events would you like to trigger this webhook?", ["Just the push event.", "Send me everything.", "Let me select individual events."]),
            L("Recent deliveries", ["push · 200 · 2 minutes ago"], "Redeliver or inspect webhook payloads."),
        ]),
    ]),
    P("o-discussions", "Discussions", f"{BASE}/discussions", "comment-discussion", [
        S("Discussions", [
            CB("Enable discussions for this organization", "Setting up Discussions for your organization will allow you to broadcast updates, answer questions, and hold conversations for the entire organization."),
            SEL("Source repository", ["octo-sample-org/.github"]),
        ]),
    ]),
    P("o-packages", "Packages", f"{BASE}/packages", "package", [
        S("Package creation", [
            CB("Public", "Members will be able to create public packages, visible to anyone.", True),
            CB("Private", "Members will be able to create private packages, visible to organization members with permission.", True),
            CB("Internal", "Members will be able to create internal packages, visible to all enterprise members."),
        ]),
        S("Default package settings", [
            CB("Inherit access from source repository (recommended)", "New packages inherit access permissions from the linked repository.", True),
        ]),
        S("Deleted packages", [L("Deleted packages", ["ghcr.io/octo-sample-org/worker"]), B("Restore")]),
    ]),
    P("o-pages", "Pages", f"{BASE}/pages", "browser", [
        S("Verified domains", [
            L("Verified domains", ["docs.octo.example.invalid · Verified"], "Verify domains to restrict who can publish GitHub Pages sites to them. Verifying a domain prevents takeover attacks."),
            B("Add a domain"),
        ]),
    ]),
    P("o-hosted-compute", "Hosted compute networking", f"{BASE}/network_configurations", "server", [
        S("Network configurations", [
            L("Network configurations", ["prod-vnet · Azure private networking · 2 runner groups"], "Connect GitHub-hosted runners to your private networks with Azure Virtual Network."),
            B("New network configuration"),
        ]),
    ]),
])
