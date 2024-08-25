# best-nginx

A custom nginx image with some additional modules and some functionality removed. Perfect as a reverse proxy.

## Notable Features:
- http/3 support (quic)
- brotli support
- headers-more-nginx-module
- geoip2 support
- removed many modules that are not needed for a reverse proxy
- packaged inside a slim alpine image without build dependencies


### Run
```
docker run -d -p 80:80 -p 443:443 -v /path/to/nginx.conf:/etc/nginx/nginx.conf ghcr.io/vojkovic/best-nginx/best-nginx:latest
```

As docker compose:

```yaml
services:
  nginx:
    image: ghcr.io/vojkovic/best-nginx/best-nginx:latest
    network_mode: host
    volumes:
      - /path/to/nginx.conf:/etc/nginx/nginx.conf
```