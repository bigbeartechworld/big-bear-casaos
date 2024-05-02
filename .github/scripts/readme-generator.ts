import fs from "fs";

type App = {
  name: string;
  dockerImage: string;
  version: string;
  youtubeVideo: string;
  docs: string;
};

const getAppsList = async () => {
  const apps: Record<string, App> = {};
  const res = await fetch(
    "https://api.github.com/repos/bigbeartechworld/big-bear-runtipi/contents/apps"
  );

  if (!res.ok) {
    console.error(`Failed to fetch app list, status: ${res.status}`);
    return { apps };
  }

  const data = await res.json();
  const appNames = data.map((app) => app.name);

  for (const app of appNames) {
    const configUrl = `https://raw.githubusercontent.com/bigbeartechworld/big-bear-runtipi/master/apps/${app}/config.json`;
    const configRes = await fetch(configUrl);

    if (!configRes.ok) {
      console.error(
        `Failed to fetch config for ${app}, status: ${configRes.status}`
      );
      continue;
    }

    try {
      const appConfig = await configRes.json();
      apps[app] = {
        name: appConfig.id || "N/A",
        dockerImage: appConfig.image || "N/A",
        version: appConfig.version || "N/A",
        youtubeVideo: appConfig.youtube || "",
        docs: appConfig.docs_link || "",
      };
    } catch (e) {
      console.error(`Error parsing config for ${app}: ${e.message}`);
    }
  }

  return { apps };
};

const appToMarkdownTable = (apps: Record<string, App>) => {
  let table = `| Application | Docker Image | Version | YouTube Video | Docs |\n`;
  table += `| --- | --- | --- | --- | --- |\n`;

  Object.values(apps).forEach((app) => {
    table += `| ${app.name} | ${app.dockerImage} | ${app.version} | [YouTube Video](${app.youtubeVideo}) | [Docs](${app.docs}) |\n`;
  });

  return table;
};

const writeToReadme = (appsTable) => {
  const baseReadme = fs.readFileSync(
    __dirname + "/../../templates/README.md",
    "utf8"
  );
  const finalReadme = baseReadme.replace("<!appsList>", appsTable);
  fs.writeFileSync(__dirname + "/../../README.md", finalReadme);
};

const main = async () => {
  const apps = await getAppsList();
  const markdownTable = appToMarkdownTable(apps.apps);
  writeToReadme(markdownTable);
};

main();
