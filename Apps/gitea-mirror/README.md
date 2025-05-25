# Gitea Mirror

Gitea Mirror is a modern web app for automatically mirroring repositories from GitHub to your self-hosted Gitea instance. It can mirror personal repositories, starred repositories, and organization repositories.

## Features

- 🔁 Sync public, private, or starred GitHub repos to Gitea
- 🏢 Mirror entire organizations with structure preservation
- 🐞 Optional mirroring of issues and labels
- 🌟 Mirror your starred repositories
- 🕹️ Modern user interface with toast notifications and smooth experience
- 🧠 Smart filtering and job queue with detailed logs
- 🛠️ Works with personal access tokens (GitHub + Gitea)
- 🔒 First-time user signup experience with secure authentication
- ⏱️ Scheduled automatic mirroring

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

- `JWT_SECRET`: Secret key for JWT authentication (important for security)
- `GITHUB_USERNAME`: Your GitHub username
- `GITHUB_TOKEN`: Your GitHub personal access token
- `GITEA_URL`: The URL of your Gitea instance
- `GITEA_TOKEN`: Your Gitea access token
- `GITEA_USERNAME`: Your Gitea username

## Access

The web interface is available at port 4321.

## Data Storage

The application uses SQLite for data storage, with the database file stored in the mounted volume at `/app/data`.
