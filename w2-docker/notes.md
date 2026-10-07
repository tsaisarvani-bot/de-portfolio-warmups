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