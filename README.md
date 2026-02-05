# CRKN Canadiana Blacklight

CRKN Canadiana Blacklight is a Rails 7 + Blacklight 8.8 app for search and discovery over MARC records, backed by Solr and integrated with IIIF (manifest + content search) endpoints, using [Mirador](https://github.com/ProjectMirador/mirador) viewer for IIIF Manifest Display.

## Quick Start (Docker, recommended)

1. Install Docker Desktop.
1. Copy `.env.example` to `.env`.
1. Fill in the values in `.env`.
1. Optional: create a master key if you plan to use encrypted credentials.
   ```bash
   ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
   ```
   Save that value to `config/master.key` or export it as `RAILS_MASTER_KEY`.
1. Run the app.
   ```bash
   docker compose up --build --force-recreate
   ```

The app will be available at `http://localhost:3000`.

Note: Docker Compose only runs the Rails app. You must provide a Solr core and update `config/blacklight.yml` if needed.

## Docker Desktop + WSL2 (Windows + Ubuntu)

These steps set up Docker Desktop to build containers in Ubuntu on WSL2.

1. Install Docker Desktop (Windows).
1. Ensure Docker Desktop uses the WSL2 engine: Docker Desktop -> Settings -> General -> check `Use the WSL 2 based engine`.
1. Install WSL + Ubuntu in PowerShell (Admin).
   ```powershell
   wsl --install -d Ubuntu
   ```

1. Reboot if prompted.
1. Launch Ubuntu from the Start menu or run `wsl`.
1. Update Ubuntu packages.
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

1. In Ubuntu, navigate to the repo and build.
   ```bash
   cd /mnt/c/Users/BrittnyLapierre/Documents/github/crkn_canadiana_blacklight
   docker compose build
   ```

## Quick Start (Local Ruby)

1. Install Ruby 3.4.1 and Bundler.
1. Install Node.js and Yarn 4.2.2 (Corepack).
1. Run `bundle install`.
1. Run `yarn install`.
1. Copy `.env.example` to `.env` and fill in values.
1. Run `bin/rails server`.

Optional: run `bin/vite dev` in another terminal for faster frontend rebuilds.

You can also run `bin/setup` to install dependencies.

## Configuration and Secrets (.env)

`.env` is loaded in development and test via `dotenv-rails`.

Required variables:

- `IIIF_MANIFEST_BASE` - Base URL for IIIF manifests.
- `IIIF_CONTENT_SEARCH_BASE` - Base URL for IIIF Content Search.
- `RAILS_ENV` - Use `development` for local work.
- `SECRET_KEY_BASE` - Needed for production-like use. Generate with `bin/rails secret`.

Optional variables for Swift-backed download links:

- `CAP_PASS` - HMAC key used to sign Swift URLs.
- `SWIFT_AUTH_URL`
- `SWIFT_USERNAME`
- `SWIFT_PASSWORD`
- `SWIFT_PREAUTH_URL`

Do not commit `.env`.

## Solr

Blacklight requires a Solr core for search. Configure the connection in `config/blacklight.yml`.

Local options:

- Point `config/blacklight.yml` to an existing Solr core.
- Run your own Solr and use the config in `data/data/blacklight_marc/conf`.

Index a MARC record:

```bash
rake solr:marc:index MARC_FILE=marc-file-name-here.mrc
```

Clear the Solr index:

```bash
curl -X POST -H "Content-Type: application/json" "http://username:password@host/solr/blacklight_marc_demo/update?commit=true" -d '{ "delete": {"query":"*:*"} }'
curl -X POST -H "Content-Type: application/json" "http://localhost:8983/solr/blacklight_marc_demo/update?commit=true" -d '{ "delete": {"query":"*:*"} }'
```

### Production Solr Setup (CRKN)

For CRKN production, Solr runs outside of Docker Compose. High-level steps:

1. SSH to the Solr container.
1. Create the `blacklight_marc` core and `conf` directory.
1. Copy the default configset.
1. Replace `solrconfig.xml` and `managed-schema.xml` with the versions from this repo.
1. Restart Solr.

Commands:

```bash
sudo cat /home/bitnami/bitnami_credentials
ssh -i ~/.ssh/<id file>.pem <user>@4.229.225.26
sudo mkdir /opt/bitnami/solr/server/solr/blacklight_marc_demo
sudo mkdir /opt/bitnami/solr/server/solr/blacklight_marc_demo/conf
sudo cp -r /opt/bitnami/solr/server/solr/configsets/_default/conf/* /opt/bitnami/solr/server/solr/blacklight_marc_demo/conf/
cd /opt/bitnami/solr/server/solr/blacklight_marc_demo/conf/
sudo rm solrconfig.xml
sudo vi solrconfig.xml
sudo rm managed-schema.xml
sudo vi managed-schema.xml
```

Ensure the following users and permissions are configured in `security.json`:

```json
{
  "authorization": {
    "class": "solr.RuleBasedAuthorizationPlugin",
    "permissions": [
      {
        "name": "read",
        "role": [
          "admin",
          "public"
        ]
      },
      {
        "name": "all",
        "role": "admin"
      }
    ],
    "user-role": {
      "admin": "admin",
      "public": "public",
      "manager": "admin"
    }
  }
}
```

Restart Solr to apply the changes:

```bash
sudo /opt/bitnami/ctlscript.sh restart solr
```

## Project Map

- `app/controllers/catalog_controller.rb` - Search UI entry point.
- `app/controllers/downloads_controller.rb` - IIIF and Swift-backed download links.
- `app/models/search_builder.rb` - Solr query construction.
- `app/models/solr_document.rb` - Solr document mapping.
- `app/models/marc_indexer.rb` - MARC indexing.
- `config/blacklight.yml` - Solr connection settings.
- `config/initializers/blacklight.rb` - Blacklight configuration.
- `config/initializers/canadiana_endpoints.rb` - IIIF endpoint configuration.
- `data/data/blacklight_marc/conf` - Solr schema and config.
- `deployImage.sh` - Build and push deployment image.

## Development

Run the container:
```bash
docker compose up
```

Common in-container commands:

- `bin/rails server` - Start the app.
- `bin/rails console` - Interactive Rails console.
- `bin/rails routes` - List routes and controllers.
- `bin/rails test` - Run tests.
- `bin/vite dev` - Run the Vite dev server.

## Deployment (CRKN Servers)

We deploy to CRKN internal servers using `./deployImage.sh`, which builds and pushes the image to the internal Docker registry.

Prereqs:

- Docker Desktop installed and running (Linux containers).
- VPN connected (OpenVPN), if required for registry access.
- Registry credentials from 1Password (item: `docker.c7a.ca`).

Deploy:

```bash
./deployImage.sh
```

Notes:

- The script tags the image with a UTC timestamp and optional branch suffix.
- The script prints a link to create a Systems-Administration issue. Create it and include the image tag.

## Docs

- Blacklight Wiki: https://github.com/projectblacklight/blacklight/wiki/
- Blacklight Workshop: https://workshop.projectblacklight.org/
- IIIF overview: https://iiif.io/
- IIIF Content Search API v2: https://iiif.io/api/search/2.0/
