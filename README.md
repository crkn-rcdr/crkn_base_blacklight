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
- `CANADIANA_CATALOGUE_URL` - Canadiana Collection search endpoint. Defaults to `https://www-beta.canadiana.ca/catalogue`.
- `HERITAGE_CATALOGUE_URL` - Héritage Collection search endpoint. Defaults to `https://heritage-beta.canadiana.ca/catalogue`.

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

In production, Solr runs in Docker containers (Solr 9+). The core data directory must be persisted via a Docker volume or host bind-mount to `/var/solr/data`.

> **Important:** The schema requires ICU token filters. Ensure each Solr container is launched with the `analysis-extras` module enabled:
> `SOLR_MODULES=analysis-extras`

#### Core Naming (Canadiana vs. Heritage)

CRKN maintains two Solr setups (one for Canadiana, one for Heritage). Heritage cores append `_heritage` to the core name:
- **Canadiana:** `blacklight_marc`
- **Heritage:** `blacklight_marc_heritage`

*(Note: The other microservice cores follow the exact same convention: `ark_map` / `ark_map_heritage`, `ark_counter` / `ark_counter_heritage`, and `content_search` / `content_search_heritage`.)*

#### 1. Setting Up Canadiana (`blacklight_marc`)

1. **Create the core from the default configset:**
   Exec into the Solr container as the `solr` user to create the core (this seeds the baseline `_default` configset including language stopwords):
   ```bash
   docker exec -it -u solr <solr-canadiana-container> solr create_core -c blacklight_marc
   ```

2. **Deploy custom schema and config from this repository:**
   Copy `solrconfig.xml` and `managed-schema.xml` from `data/data/blacklight_marc/conf/` into the core's `conf` directory:
   ```bash
   docker cp data/data/blacklight_marc/conf/solrconfig.xml <solr-canadiana-container>:/var/solr/data/blacklight_marc/conf/
   docker cp data/data/blacklight_marc/conf/managed-schema.xml <solr-canadiana-container>:/var/solr/data/blacklight_marc/conf/
   ```

   *(Optional if mounting directly on host)*: If managing files on a host bind-mount directly, copy the files into `<mount_path>/blacklight_marc/conf/` and ensure file ownership matches the Solr process (`chown -R 8983:8983 <mount_path>/blacklight_marc`).

3. **Reload the core or restart Solr:**
   ```bash
   docker exec <solr-canadiana-container> curl -s "http://localhost:8983/solr/admin/cores?action=RELOAD&core=blacklight_marc"
   # or: docker restart <solr-canadiana-container>
   ```

4. **Verify core status:**
   ```bash
   docker exec <solr-canadiana-container> curl -s "http://localhost:8983/solr/blacklight_marc/admin/ping"
   ```

#### 2. Setting Up Heritage (`blacklight_marc_heritage`)

If Canadiana is already configured, you can save time by copying the configs directly from the existing Canadiana core:

1. **Create the Heritage core:**
   ```bash
   docker exec -it -u solr <solr-heritage-container> solr create_core -c blacklight_marc_heritage
   ```

2. **Copy configs from existing Canadiana:**
   Copy the `conf/` directory contents from `blacklight_marc` into `blacklight_marc_heritage`:
   ```bash
   # If cores share the same host filesystem / volume:
   cp -r /var/solr/data/blacklight_marc/conf/* /var/solr/data/blacklight_marc_heritage/conf/
   ```
   > **Note for other microservice cores:** You can use the exact same shortcut for `ark_map`, `ark_counter`, and `content_search` — create the core with `_heritage` appended and copy over the configuration files from the corresponding Canadiana core:
   > - `ark_map` $\rightarrow$ `ark_map_heritage`
   > - `ark_counter` $\rightarrow$ `ark_counter_heritage`
   > - `content_search` $\rightarrow$ `content_search_heritage`

3. **Reload the core or restart Solr:**
   ```bash
   docker exec <solr-heritage-container> curl -s "http://localhost:8983/solr/admin/cores?action=RELOAD&core=blacklight_marc_heritage"
   # or: docker restart <solr-heritage-container>
   ```

4. **Verify core status:**
   ```bash
   docker exec <solr-heritage-container> curl -s "http://localhost:8983/solr/blacklight_marc_heritage/admin/ping"
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
