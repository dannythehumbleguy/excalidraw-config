.PHONY: run down ssl ssl-renew logs logs-app restart

run:
	docker compose up -d

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
	docker compose logs -f excalidraw

restart:
	docker compose restart excalidraw nginx
