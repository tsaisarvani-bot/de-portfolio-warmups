# W2: Docker Basics

## Key terms
-Image: A read-only template that contains everything needed to run an application. `postgres:16` is the official image for PostgreSQL version 16.
-Container: A running instance of an image. One image can run many containers, and each container is isolated from the others.
-Port mapping: Connects a port on my laptop to a port inside the container. Without it, tools like DBeaver can't reach the database inside the container.
-Volume: Storage managed by Docker that lives outside the container. Data in a volume survives when the container is stopped or deleted.

## The command I used
```
docker run --name pg-w2 `
  -e POSTGRES_USER=de `
  -e POSTGRES_PASSWORD=de_pass `
  -e POSTGRES_DB=warmups `
  -p 5432:5432 `
  -v pgdata_w2:/var/lib/postgresql/data `
  -d postgres:16
```

| Flag | What it does |
|------|--------------|
| `--name pg-w2` | Gives the container a fixed name, so I can refer to it instead of using a random ID |
| `-e POSTGRES_USER=de` | Sets an environment variable that creates the database user `de` |
| `-e POSTGRES_PASSWORD=de_pass` | Sets that user's password |
| `-e POSTGRES_DB=warmups` | Creates a database called `warmups` on first start |
| `-p 5432:5432` | Maps laptop port 5432 to container port 5432 (format is `laptop:container`) |
| `-v pgdata_w2:/var/lib/postgresql/data` | Stores Postgres's data folder in a named volume called `pgdata_w2` |
| `-d` | Runs the container in the background (detached), so my terminal stays free |
| `postgres:16` | The image to run, as `name:tag` |

## Other useful commands
- `docker ps`: list running containers (add `-a` to include stopped ones)
- `docker logs pg-w2`: see the container's output, which is the first place to look when something fails
- `docker exec -it pg-w2 psql -U de -d warmups`: open a Postgres prompt inside the container
- `docker stop pg-w2` / `docker rm pg-w2`: stop the container / delete it
- `docker volume ls`: list volumes

## Volume test: what happened
1. I created a table `test_patients` with two rows.
2. I stopped and deleted the container with `docker stop` and `docker rm`.
3. I ran the same `docker run` command again, which created a brand-new container.
4. The two rows were still there.

**Why:** The data was written to the `pgdata_w2` volume, not to the container itself. The new container attached to the same volume and found the existing data. Without `-v`, the data would have been lost when the container was deleted.

**Lesson:** Containers are disposable, but data must be persistent. Always use a volume for databases.

## Connecting from DBeaver
Host `localhost`, port `5432`, database `warmups`, user `de`. This works because of the `-p` port mapping.

## Note on passwords
The password is in plain text here because this is a local practice database. In real projects, credentials go in a `.env` file that is listed in `.gitignore`, or in a secrets manager, and never in Git.

## Part 2: Docker Compose

1. What problem does Docker Compose solve compared with docker run?
With docker run, you type a long command for each container and have to remember every flag. With several services, you'd also have to start them in the right order and connect them yourself. Compose puts all of that in one file, docker-compose.yml, so docker compose up -d starts everything and docker compose down stops everything. Because the setup lives in a file, it's saved in Git and anyone can rerun it exactly.

Interview line: "Compose turns a multi-container setup into a single, version-controlled file you can start with one command."

2. Why does pgAdmin use postgres as the host instead of localhost?
Each container has its own localhost, which means "this container." Inside pgAdmin's container, localhost points to pgAdmin itself, where no database is running. Compose puts all services on a shared network where they find each other by service name, so pgAdmin reaches the database at postgres. DBeaver uses localhost:5432 because it runs on your laptop, not inside a container, and the port mapping connects your laptop to the container.

Interview line: "Containers talk to each other by service name on the Compose network; localhost inside a container means the container itself."

3. What happened to p4 after down, and after down -v? Why?
After down, p4 survived. down removes the containers and network but keeps the volume, where Postgres stores its data, so the new container reattached to the same data.
After down -v, p4 was gone. -v also deletes the volume, so Postgres started with empty storage and the init script recreated only p1–p3. p4 was added by hand and wasn't in any script, so nothing could bring it back.

Interview line: "Containers are disposable; volumes hold the state. down -v deletes the state."

4. Why did pgAdmin forget your server after down?
pgAdmin saves your login and registered servers inside its own container. The compose file gave Postgres a volume, but not pgAdmin. When down deleted the pgAdmin container, those settings were deleted with it. Adding a volume for pgAdmin (for example pgadmin_data:/var/lib/pgadmin) would make them persist.

Interview line: "Any data a container needs to keep must be on a volume. Otherwise it's lost when the container is removed."

5. What do healthcheck and depends_on do?
healthcheck tells Docker how to check whether Postgres is actually ready. Every 5 seconds it runs pg_isready, and the container shows healthy only when Postgres accepts connections.
depends_on with condition: service_healthy makes pgAdmin wait to start until Postgres passes that check. Without the condition, Compose only waits for the Postgres container to start, which happens several seconds before the database is ready to take connections.

Interview line: "Healthchecks define 'ready', and depends_on with service_healthy enforces startup order based on that, not just on the container existing."

6. Why is .env kept out of Git while .env.example is committed?
.env holds real secrets: usernames and passwords. Anything pushed to a public repo can be seen and copied by anyone, and it stays in the Git history even if you delete it later. .env.example has the same variable names with empty values. It tells someone cloning the repo which settings they need, without exposing yours. They copy it to .env and fill in their own values.