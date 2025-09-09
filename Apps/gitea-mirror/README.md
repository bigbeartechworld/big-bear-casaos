# Gitea Mirror (v3.6.0)

Gitea Mirror is a modern web app for automatically mirroring repositories from GitHub to your self-hosted Gitea instance. It can mirror personal repositories, starred repositories, and organization repositories.

## Features

- 🔁 Mirror public, private, and starred GitHub repos to Gitea
- 🏢 Mirror entire organizations with flexible strategies
- 🎯 Custom destination control for repos and organizations
- 📦 **Git LFS support** - Mirror large files with Git LFS
- 📝 **Metadata mirroring** - Issues, pull requests (as issues), labels, milestones, wiki
- 🚫 **Repository ignore** - Mark specific repos to skip
- 🔐 Secure authentication with Better Auth (email/password, SSO, OIDC)
- 📊 Real-time dashboard with activity logs
- ⏱️ Scheduled automatic mirroring with configurable intervals
- 🔄 **Auto-discovery** - Automatically import new GitHub repositories
- 🧹 **Repository cleanup** - Auto-remove repos deleted from GitHub
- 🎯 **Proper mirror intervals** - Respects configured sync intervals
- 🗑️ Automatic database cleanup with configurable retention
- 🐳 Dockerized with multi-arch support (AMD64/ARM64)

## Getting Started

On first launch, you'll be guided through creating an admin account with your chosen credentials.

After logging in, you can configure the application through the UI:

1. Go to the **Configuration** tab
2. Set up your GitHub connection (username and token)
3. Set up your Gitea connection (URL, username, and token)
4. Configure mirroring options (repositories, organizations, etc.)

## Configuration Options

All of these options can be configured through the UI after installation:

- **GitHub Connection**: Username and personal access token
- **Gitea Connection**: URL, username, and access token
- **Repository Options**: Include/exclude forks, private repositories
- **Mirroring Options**: Mirror issues, starred repositories, organizations
- **Organization Options**: Preserve structure, organization visibility
- **Scheduling**: Automatic mirroring interval

## Environment Variables

While most configuration can be done through the UI, you can also pre-configure the application using environment variables:

- `BETTER_AUTH_SECRET`: Secret key for Better Auth authentication (important for security)
- `BETTER_AUTH_URL`: Authentication URL (defaults to http://0.0.0.0:4321)
- `GITHUB_USERNAME`: Your GitHub username
- `GITHUB_TOKEN`: Your GitHub personal access token
- `GITEA_URL`: The URL of your Gitea instance
- `GITEA_TOKEN`: Your Gitea access token
- `GITEA_USERNAME`: Your Gitea username
- `SCHEDULE_ENABLED`: Enable automatic scheduled mirroring
- `GITEA_MIRROR_INTERVAL`: Mirror interval (e.g., "8h" for 8 hours)

## Access

The web interface is available at port 4321.

## Data Storage

The application uses SQLite for data storage, with the database file stored in the mounted volume at `/app/data`.
