module.exports = {
  extends: ["config:recommended", ":dependencyDashboard"], // Extending a base configuration named "config:base"
  onboarding: true, // Disabling onboarding process
  rebaseWhen: "conflicted", // Rebase when there are conflicts
  gitIgnoredAuthors: ["githubaction@githubaction.com"], // Ignoring commits from a specific author
  dependencyDashboard: true, // Enabling the dependency dashboard
  enabledManagers: ["docker-compose", "dockerfile"], // Enabling specific package managers

  hostRules: [
    {
      matchHost: "index.docker.io", // Matching a specific host
      hostType: "docker", // Defining the host type as "docker"
      username: process.env.DOCKERHUB_USERNAME, // Setting the username from environment variables
      password: process.env.DOCKERHUB_TOKEN, // Setting the password from environment variables
    },
    {
      matchHost: "docker.io", // Matching another specific host
      concurrentRequestLimit: 2, // Limiting concurrent requests to 2 for this host
    },
  ],

  packageRules: [
    {
      matchManagers: ["docker-compose", "dockerfile"], // Applying rules to specific package managers
      matchPackagePatterns: [
        "^([^\\/]+\\/)?(mysql|mariadb|mongodb|mongo|postgres|redis)(:|$)",
      ], // Defining package patterns using regular expressions
      enabled: false, // Disabling this rule
    },
  ],
};
