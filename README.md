# Deploy

1. On a Linux server with Docker Compose and Make installed, point your domain
   to the server and open ports 80 and 443.
2. If `.env` does not exist, create it:

   ```sh
   cp .env.example .env
   ```

3. Set `DOMAIN`, `SSL_EMAIL`, and `POSTGRES_PASSWORD` in `.env`.
   Generate a password with `openssl rand -hex 32`. Keep the default certificate paths.
4. Create the certificate and start the stack:

   ```sh
   docker compose --profile ssl pull
   make ssl
   make run
   ```

5. Open `https://YOUR_DOMAIN`.
6. Renew the certificate when due:

   ```sh
   make ssl-renew
   ```
