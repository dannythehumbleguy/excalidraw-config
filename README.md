# Deploy

1. On a Linux server with Docker Compose and Make installed, point your domain
   to the server and open ports 80 and 443.
2. If `.env` does not exist, create it:

   ```sh
   cp .env.example .env
   ```

3. Set `DOMAIN` and `SSL_EMAIL` in `.env`. Set `API_KEY_HASH_PEPPER` to the output
   of `openssl rand -hex 32` once; keep it unchanged. Keep the default certificate paths.
4. Create the certificate and start the stack:

   ```sh
   docker compose --profile ssl pull
   make ssl
   make run
   ```

5. Open `https://YOUR_DOMAIN` and follow ExcaliDash's setup to enable
   authentication and create the first administrator. Get the setup code with:

   ```sh
   docker compose logs backend --tail=200 | grep 'BOOTSTRAP SETUP'
   ```

6. Use the administrator's user-management page to add users. Each user can
   save personal drawings and share them with others. Data stays in `./data/excalidash/`.
   Existing drawings from the previous stack require import; its `./data/postgres/` is preserved.
7. Renew the certificate when due:

   ```sh
   make ssl-renew
   ```
