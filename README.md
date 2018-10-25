# nginx-gitlab

## Install

Prerequisite: Install the [reverse proxy](https://github.com/Starli0n/nginx-proxy)

```sh
> git clone https://github.com/Starli0n/nginx-gitlab
> cd nginx-gitlab
> make init
```

## Configure

- Customize the `.env` file
- Customize `./gitlab/config/gitlab.rb` file
	- Change `external_url` by the correct hostname

## Usage

### Development

- Start the server
```
# Shortcut for docker-compose -f docker-compose.yml -f docker-compose.override.yml up
> docker-compose up
```
- Stop the server
```
# Shortcut for docker-compose -f docker-compose.yml -f docker-compose.override.yml down
> docker-compose down
```

### Production

In production, the reverse proxy should be started as well.

- Start the server
```
# docker-compose -f docker-compose.yml -f up -d
> make up
```
- Stop the server
```
# docker-compose -f docker-compose.yml -f down
> make down
```

- `https://gitlab.example.com` should respond

## Debug

- Explore the `gitlab` container
```
# docker exec -it nginx-gitlab /bin/bash
make shell
```

## Update

- Update gitlab docker image by changing the tag in `.env`
- Run `./update.sh` after an update of the gitlab configuration file `./gitlab/config/gitlab.rb`

## Create a backup

```
make backup-create
```

## Restore a backup

```
make backup-restore
```
