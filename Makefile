.PHONY: run down ssl ssl-renew logs logs-app restart nginx

run:
	docker compose -f compose.yaml -f compose.host.yml up -d

nginx:
	DOMAIN="$$(docker compose config --environment | sed -n 's/^DOMAIN=//p')"; \
	CERTS_DIR="$$(docker compose config --environment | sed -n 's/^CERTS_DIR=//p')"; \
	TLS_CERT_FILE="$$(docker compose config --environment | sed -n 's/^TLS_CERT_FILE=//p')"; \
	TLS_KEY_FILE="$$(docker compose config --environment | sed -n 's/^TLS_KEY_FILE=//p')"; \
	export DOMAIN HOST_TLS_CERT="$$(realpath -ms "$${CERTS_DIR:-./certs}/$${TLS_CERT_FILE:-live/$$DOMAIN/fullchain.pem}")" HOST_TLS_KEY="$$(realpath -ms "$${CERTS_DIR:-./certs}/$${TLS_KEY_FILE:-live/$$DOMAIN/privkey.pem}")"; \
	envsubst '$${DOMAIN} $${HOST_TLS_CERT} $${HOST_TLS_KEY}' < nginx/excalidraw.host.conf.template > /etc/nginx/conf.d/excalidraw.conf
	nginx -t
	systemctl reload nginx

down:
	docker compose down

ssl:
	docker compose stop nginx
	docker compose run --rm --service-ports certbot

ssl-renew:
	docker compose stop nginx
	docker compose run --rm --service-ports certbot renew
	docker compose start nginx

logs:
	docker compose logs -f

logs-app:
	docker compose logs -f excalidraw backend

restart:
	docker compose -f compose.yaml -f compose.host.yml restart backend excalidraw
