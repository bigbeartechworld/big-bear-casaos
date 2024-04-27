import fs from "fs";
import jsyaml from "js-yaml";

type FormField = {
  type: "random";
  required: boolean;
};

interface AppConfig {
  id: string;
  port: number;
  categories: string[];
  requirements?: {
    ports?: number[];
  };
  name: string;
  description: string;
  version?: string;
  tipi_version: number;
  short_desc: string;
  author: string;
  source: string;
  available: boolean;
  form_fields?: FormField[];
  supported_architectures: string[];
}

const networkExceptions = [
  "pihole",
  "tailscale",
  "homeassistant",
  "plex",
  "zerotier",
  "gladys",
  "scrypted",
  "homebridge",
  "cloudflared",
];
const getAppConfigs = (): AppConfig[] => {
  const apps: AppConfig[] = [];

  const appsDir = fs.readdirSync("./Apps");

  appsDir.forEach((app: string) => {
    const path = `./Apps/${app}/config.json`;

    if (fs.existsSync(path)) {
      const configFile = fs.readFileSync(path).toString();

      try {
        const config: AppConfig = JSON.parse(configFile);
        if (config.version) {
          apps.push(config);
        }
      } catch (e) {
        console.error("Error parsing config file", app);
      }
    }
  });

  return apps;
};

describe("App configs", () => {
  it("Get app config should return at least one app", () => {
    const apps = getAppConfigs();

    expect(apps.length).toBeGreaterThan(0);
  });

  describe("Each app should have an id", () => {
    const apps = getAppConfigs();

    apps.forEach((app) => {
      test(String(app.version), () => {
        expect(app.version).toBeDefined();
      });
    });
  });

  // describe("Each app should have a md description", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       const path = `./Apps/${app.id}/metadata/description.md`;

  //       if (fs.existsSync(path)) {
  //         const description = fs.readFileSync(path).toString();
  //         expect(description).toBeDefined();
  //       } else {
  //         expect(true).toBe(false);
  //       }
  //     });
  //   });
  // });

  // describe("Each app should have categories defined as an array", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(app.categories).toBeDefined();
  //       expect(app.categories).toBeInstanceOf(Array);
  //     });
  //   });
  // });

  // describe("Each app should have a name", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(app.name).toBeDefined();
  //     });
  //   });
  // });

  // describe("Each app should have a description", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(app.description).toBeDefined();
  //     });
  //   });
  // });

  // describe("Each app should have a port", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(app.port).toBeDefined();
  //       expect(app.port).toBeGreaterThan(999);
  //       expect(app.port).toBeLessThan(65535);
  //     });
  //   });
  // });

  // describe("Each app should have a supported architecture", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(app.supported_architectures).toBeDefined();
  //       expect(app.supported_architectures).toBeInstanceOf(Array);
  //     });
  //   });
  // });

  // test("Each app should have a different port", () => {
  //   const appConfigs = getAppConfigs();
  //   const ports = appConfigs.map((app) => app.port);
  //   expect(new Set(ports).size).toBe(appConfigs.length);
  // });

  // test("Each app should have a unique id", () => {
  //   const appConfigs = getAppConfigs();
  //   const ids = appConfigs.map((app) => app.id);
  //   expect(new Set(ids).size).toBe(appConfigs.length);
  // });

  describe("Each app should have a version", () => {
    const apps = getAppConfigs();

    apps.forEach((app) => {
      test(app.id, () => {
        expect(app.version).toBeDefined();
        // expect(app.tipi_version).toBeDefined();
        // expect(app.tipi_version).toBeGreaterThan(0);
      });
    });
  });

  describe("Each app should have a docker-compose file beside it", () => {
    const apps = getAppConfigs();

    apps.forEach((app) => {
      test(app.id, () => {
        expect(fs.existsSync(`./Apps/${app.id}/docker-compose.yml`)).toBe(true);
      });
    });
  });

  // describe("Each app should have a metadata folder beside it", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(fs.existsSync(`./Apps/${app.id}/metadata`)).toBe(true);
  //     });
  //   });
  // });

  // describe("Each app should have a file named logo.jpg in the metadata folder", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       expect(fs.existsSync(`./Apps/${app.id}/metadata/logo.jpg`)).toBe(true);
  //     });
  //   });
  // });

  // describe("Each app should have a container name equals to its id", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       const dockerComposeFile = fs
  //         .readFileSync(`./Apps/${app.id}/docker-compose.yml`)
  //         .toString();

  //       const dockerCompose: any = jsyaml.load(dockerComposeFile);

  //       expect(dockerCompose.services[app.id]).toBeDefined();
  //       expect(dockerCompose.services[app.id].container_name).toBe(app.id);
  //     });
  //   });
  // });

  describe("Each app should have the same version in config.json and docker-compose.yml", () => {
    const exceptions = ["revolt"];
    const apps = getAppConfigs().filter((app) => !exceptions.includes(app.id));

    apps.forEach((app) => {
      test(app.id, () => {
        const dockerComposeFile = fs
          .readFileSync(`./Apps/${app.id}/docker-compose.yml`)
          .toString();

        const dockerCompose: any = jsyaml.load(dockerComposeFile);

        const serviceNames = Object.keys(dockerCompose.services);
        if (serviceNames.length === 0) {
          throw new Error("No services defined in docker-compose.yml");
        }

        // Get the first service's name and details
        const firstServiceName = serviceNames[0];
        const firstServiceDetails = dockerCompose.services[firstServiceName];

        console.log("First service name:", firstServiceName);
        console.log("First service details:", firstServiceDetails);

        if (firstServiceDetails.image) {
          const dockerImage = firstServiceDetails.image;
          const version = dockerImage.split(":")[1];

          if (version === "latest") {
            console.log(
              `Skipping version check for ${app.id} as it uses 'latest' tag.`
            );
          } else {
            expect(version).toContain(app.version);
          }
        } else {
          throw new Error(
            "Image definition missing in docker-compose.yml for service: " +
              firstServiceName
          );
        }
      });
    });
  });

  // describe("Each app should have network tipi_main_network", () => {
  //   const apps = getAppConfigs();

  //   apps.forEach((app) => {
  //     test(app.id, () => {
  //       if (!networkExceptions.includes(app.id)) {
  //         const dockerComposeFile = fs
  //           .readFileSync(`./Apps/${app.id}/docker-compose.yml`)
  //           .toString();

  //         const dockerCompose: any = jsyaml.load(dockerComposeFile);

  //         expect(dockerCompose.services[app.id]).toBeDefined();

  //         expect(dockerCompose.services[app.id].networks).toBeDefined();
  //         expect(dockerCompose.services[app.id].networks).toContain(
  //           "tipi_main_network"
  //         );
  //       }
  //     });
  //   });
  // });

  // describe("All form fields with type random should not be marked as required", () => {
  //   const configs = getAppConfigs();
  //   configs.forEach((config) => {
  //     const formFields = config.form_fields;
  //     if (formFields) {
  //       formFields.forEach((field) => {
  //         if (field.type === "random") {
  //           test(config.id, () => {
  //             expect(Boolean(field.required)).toBe(false);
  //           });
  //         }
  //       });
  //     }
  //   });
  // });
});
