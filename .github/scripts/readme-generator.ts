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
  // fetch apps from app store repo
  const res = await fetch(
    "https://api.github.com/repos/bigbeartechworld/big-bear-runtipi/contents/apps"
  );

  const data = await res.json();
  const appNames = data.map((app) => app.name);

  for (const app of appNames) {
    const config = await fetch(
      `https://raw.githubusercontent.com/bigbeartechworld/big-bear-runtipi/master/apps/${app}/config.json`
    );
    const appConfig = await config.json();

    if (!appConfig.deprecated) {
      apps[app] = {
        name: appConfig.id || "N/A",
        dockerImage: appConfig.image || "N/A",
        version: appConfig.version || "N/A",
        youtubeVideo: appConfig.youtube || "",
        docs: appConfig.docs_link || "",
      };
    }
  }

  return { apps };
};

const appToMarkdownTable = (apps) => {
  let table = `| Application | Docker Image | Version | YouTube Video | Docs |\n`;
  table += `| --- | --- | --- | --- | --- |\n`;

  Object.values(apps).forEach((app: any) => {
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
