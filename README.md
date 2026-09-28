# CRKN Blacklight

CRKN Canadiana Blacklight is a Rails 7 + Blacklight 8.8 app for search and discovery over MARC records, backed by Solr and integrated with IIIF (manifest + content search) endpoints, using [Mirador](https://github.com/ProjectMirador/mirador) viewer for IIIF Manifest Display.

## Quick Start (Docker, recommended)

1. Install Docker Desktop.
2. Copy `.env.example` to `.env`.
3. Fill in the values in `.env`.
4. Optional: create a master key if you plan to use encrypted credentials.
   ```bash
   ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
   ```
   Save that value to `config/master.key` or export it as `RAILS_MASTER_KEY`.
1. Run the app in development.
   ```bash
   docker compose -f docker-compose.dev.yml up --build --force-recreate
   ```

1. Run the app in production mode.
   ```bash
   docker compose -f docker-compose.prod.yml up --build --force-recreate
   ```

The app will be available at `http://localhost:3000`.

Note: Docker Compose only runs the Rails app. You must provide a Solr core and update `config/blacklight.yml` if needed.

## Docker Desktop + WSL2 (Windows + Ubuntu)

These steps set up Docker Desktop to build containers in Ubuntu on WSL2.

1. Install Docker Desktop (Windows).
2. Ensure Docker Desktop uses the WSL2 engine: Docker Desktop -> Settings -> General -> check `Use the WSL 2 based engine`.
3. Install WSL + Ubuntu in PowerShell (Admin).
   ```powershell
   wsl --install -d Ubuntu
   ```

4. Reboot if prompted.
5. Launch Ubuntu from the Start menu or run `wsl`.
6. Update Ubuntu packages.
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

7. In Ubuntu, navigate to the repo and build.
   ```bash
   cd /mnt/c/Users/BrittnyLapierre/Documents/github/crkn_canadiana_blacklight
   docker compose -f docker-compose.dev.yml build
   ```

## Quick Start (Local Ruby)

1. Install Ruby 3.4.1 and Bundler.
2. Install Node.js and Yarn 4.2.2 (Corepack).
3. Run `bundle install`.
4. Run `yarn install`.
5. Copy `.env.example` to `.env` and fill in values.
6. Run `bin/rails server`.

Optional: run `yarn vite` in another terminal for faster frontend rebuilds.

You can also run `bin/setup` to install dependencies.

## Configuration and Secrets (.env)

`.env` is loaded in development and test via `dotenv-rails`.

Required variables:

- `IIIF_MANIFEST_BASE` - Base URL for IIIF manifests.
- `IIIF_CONTENT_SEARCH_BASE` - Base URL for IIIF Content Search.
- `RAILS_ENV` - Use `development` for local work.
- `SECRET_KEY_BASE` - Needed for production-like use. Generate with `bin/rails secret`.

Optional variables for download links:

- `DOWNLOAD_API_ENDPOINT` - Download API endpoint. Defaults to `https://beta-download.canadiana.ca/download`.
- `DOWNLOAD_TOKEN_SECRET` - HMAC key used to sign Download API URLs.
- `DOWNLOAD_TOKEN_TTL` - Signed URL lifetime in seconds. Defaults to `1800`.
- `DOWNLOAD_CACHE_REDIS_URL` - Redis URL for precomputed download metadata. Defaults to `redis://redis:6379/0`.
- `DOWNLOAD_CACHE_REDIS_POOL_SIZE` - Redis connection pool size for download metadata. Defaults to `5`.
- `DOWNLOAD_CACHE_REDIS_TIMEOUT` - Redis connection/read/write timeout in seconds. Defaults to `1`.
- `IIIF_IMAGE_BASE` - IIIF Image API base used to derive full-size JPG download links. Defaults to `https://image-tor.canadiana.ca/iiif/2`.

Seed the local development download cache:

```bash
docker compose -f docker-compose.dev.yml up -d redis
docker compose -f docker-compose.dev.yml run --rm --no-deps web ruby script/seed_download_cache.rb --sample
```

Seed a full portal cache into the dev Redis:

```bash
docker compose -f docker-compose.dev.yml run --rm --no-deps web ruby script/seed_download_cache.rb --portal canadiana --full
```

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
curl -X POST -H "Content-Type: application/json" "http://username:password@host/solr/blacklight_marc/update?commit=true" -d '{ "delete": {"query":"*:*"} }'
curl -X POST -H "Content-Type: application/json" "http://localhost:8983/solr/blacklight_marc/update?commit=true" -d '{ "delete": {"query":"*:*"} }'
```

### Production Solr Setup (CRKN)
For CRKN production, Solr runs in a docker container. The data dir needs to be a volume.
High-level steps:
1. SSH to the Solr container.
2. Create the `blacklight_marc` core and `conf` directory.
3. Copy the default configset.
4. Replace `solrconfig.xml` and `managed-schema.xml` with the versions from this repo.
5. Restart Solr.

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

Run the development container:
```bash
docker compose -f docker-compose.dev.yml up --build --force-recreate
```

Run the production container:
```bash
docker compose -f docker-compose.prod.yml up --build --force-recreate
```

The default `docker-compose.yml` uses the same production-style startup flow, so `docker compose up --build --force-recreate` also works.

Common in-container commands:

- `bin/rails server` - Start the app.
- `bin/rails console` - Interactive Rails console.
- `bin/rails routes` - List routes and controllers.
- `bin/rails test` - Run tests.
- `yarn vite` - Run the Vite dev server.

Run commands in the dev container:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails console
docker compose -f docker-compose.dev.yml exec web bin/rails test
```

## Deployment (CRKN Servers)

We deploy to CRKN internal servers using `./deployImage.sh`, which builds and pushes the image to the internal Docker registry.

Prereqs:

- Docker Desktop installed and running (Linux containers).
- VPN connected (OpenVPN), if required for registry access.
- Registry credentials from 1Password.

Deploy Guide: https://github.com/crkn-rcdr/systems-administration/blob/main/wiki/platform/how-to's/platform_2.0/platform_2.0-deploy_guide.md

## Docs

- Blacklight Wiki: https://github.com/projectblacklight/blacklight/wiki/
- Blacklight Workshop: https://workshop.projectblacklight.org/
- IIIF overview: https://iiif.io/
- IIIF Content Search API v2: https://iiif.io/api/search/2.0/
- Debugging Rails: https://guides.rubyonrails.org/debugging_rails_applications.html
