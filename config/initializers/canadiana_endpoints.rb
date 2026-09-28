# Centralize configurable external endpoints and read from ENV.
Rails.configuration.x.iiif_manifest_base = ENV.fetch('IIIF_MANIFEST_BASE', 'https://www-iiif-pres.canadiana.ca/manifest')
Rails.configuration.x.iiif_content_search_base = ENV.fetch('IIIF_CONTENT_SEARCH_BASE', 'https://www-iiif-search.canadiana.ca/search')
Rails.configuration.x.iiif_image_base = ENV.fetch('IIIF_IMAGE_BASE', 'https://image-tor.canadiana.ca/iiif/2')
Rails.configuration.x.cap_pass = ENV.fetch('CAP_PASS', '')
Rails.configuration.x.download_api_endpoint = ENV.fetch('DOWNLOAD_API_ENDPOINT', 'https://beta-download.canadiana.ca/download')
Rails.configuration.x.download_token_secret = ENV.fetch('DOWNLOAD_TOKEN_SECRET', '')
Rails.configuration.x.download_token_ttl = ENV.fetch('DOWNLOAD_TOKEN_TTL', '1800').to_i
Rails.configuration.x.download_cache_redis_url = ENV.fetch('DOWNLOAD_CACHE_REDIS_URL', 'redis://redis:6379/0')
Rails.configuration.x.download_cache_redis_pool_size = ENV.fetch('DOWNLOAD_CACHE_REDIS_POOL_SIZE', '5').to_i
Rails.configuration.x.download_cache_redis_timeout = ENV.fetch('DOWNLOAD_CACHE_REDIS_TIMEOUT', '1').to_f
