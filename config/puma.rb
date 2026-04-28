max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

ssl_bind "0.0.0.0", 3000, {
  cert: File.expand_path("/app/config/ssl/__canadiana_ca.crt").to_s,
  key: File.expand_path("/app/config/ssl/__canadiana_ca.key").to_s,
  verify_mode: "none"
}

plugin :tmp_restart
