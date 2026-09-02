# Build the Flutter web bundle, then serve it from nginx.
#
# Two stages keep the runtime image small: the Flutter SDK stays in the builder
# and never reaches the served image, which is nginx plus static files.

# --- Build -------------------------------------------------------------------
# A prebuilt SDK image is used rather than cloning flutter/flutter. Cloning pulls
# roughly 200 MB and then downloads the Dart and web SDKs separately, which makes
# every build slow and dependent on three network fetches succeeding.
# Pinned to the version that builds this project locally. The image must ship a
# Dart SDK satisfying the constraint in pubspec.yaml (^3.10.0); Flutter 3.35 ships
# Dart 3.9 and fails dependency resolution.
FROM ghcr.io/cirruslabs/flutter:3.38.1 AS build

WORKDIR /app

# Dependencies resolve before the source is copied so that a code change does not
# invalidate the cached pub layer.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# .env is bundled as a Flutter asset and is not committed. It is written here from
# build arguments so the values come from the platform rather than the repository.
# All three are client-side values: the Supabase key is the anon key, which is
# restricted by row-level security and is embedded in the shipped bundle anyway.
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG BACKEND_URL
RUN printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\nBACKEND_URL=%s\n' \
        "$SUPABASE_URL" "$SUPABASE_ANON_KEY" "$BACKEND_URL" > .env

RUN flutter build web --release

# --- Serve -------------------------------------------------------------------
# nginx 1.27-alpine ships OpenSSL 3.3.3, which Trivy flags for CVE-2026-31789.
# 1.29-alpine carries 3.5.6, above the 3.3.7 fix. The apk upgrade catches patches
# released after this tag was published, since the image is scanned on every build.
FROM nginx:1.29-alpine

RUN apk upgrade --no-cache

COPY --from=build /app/build/web /usr/share/nginx/html

# Replaces the stock configuration rather than dropping a snippet into conf.d, so
# that the http-level temp paths can be redirected to /tmp. Choreo mounts the root
# filesystem read-only and nginx will not start if it cannot create them.
COPY nginx.conf /etc/nginx/nginx.conf

# Choreo requires a non-root user with a UID between 10000 and 20000. The temp
# directories are created here so nginx does not have to at startup, and /tmp is
# left world-writable for the pid file and any runtime scratch.
RUN adduser -D -u 10014 choreo \
    && mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp \
                /tmp/uwsgi_temp /tmp/scgi_temp \
    && chown -R 10014:10014 /usr/share/nginx/html /tmp \
    && chmod 1777 /tmp

USER 10014
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
