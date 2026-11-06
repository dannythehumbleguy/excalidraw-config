# Deploy

1. On a Linux server with Docker Compose and Make installed, point your domain
   to the server and open ports 80 and 443.
2. If `.env` does not exist, create it:

   ```sh
   cp .env.example .env
   ```

3. Set `DOMAIN` and `SSL_EMAIL` in `.env`. Set `API_KEY_HASH_PEPPER` to the output
   of `openssl rand -hex 32` once; keep it unchanged. Keep the default certificate paths.
4. Create the certificate while port 80 is free. For an existing certificate,
   set `CERTS_DIR`, `TLS_CERT_FILE` and `TLS_KEY_FILE` to its existing paths.
   Start the stack and install the host Nginx configuration:

   ```sh
   docker compose --profile ssl pull
   make ssl
   make run
   sudo make nginx
   ```

   Start the host Nginx before `make nginx`, and stop the previous proxy before
   starting it. If `nginx -t` fails, the generated file remains on disk and must
   be corrected before restarting Nginx.

5. Open `https://YOUR_DOMAIN` and follow ExcaliDash's setup to enable
   authentication and create the first administrator. Get the setup code with:

   ```sh
   docker compose logs backend --tail=200 | grep 'BOOTSTRAP SETUP'
   ```

6. Use the administrator's user-management page to add users. Each user can
   save personal drawings and share them with others. Data stays in `./data/excalidash/`.
   Existing drawings from the previous stack require import; its `./data/postgres/` is preserved.
7. Configure Certbot webroot renewal separately for host Nginx. The old
   standalone `make ssl-renew` is not suitable while host Nginx owns port 80.
