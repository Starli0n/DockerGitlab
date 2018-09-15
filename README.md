# DockerGitlab

## Install

Prerequisite: Install the [reverse proxy](https://github.com/Starli0n/DockerRProxy)

```sh
> git clone https://github.com/Starli0n/DockerGitlab DockerGitlab
> cd DockerGitlab
> chmod +x update.sh
> cp .env.default .env
```

## Configure

- Customize the `.env` file
- Customize `./gitlab/config/gitlab.rb` file
	- Change `external_url` by the correct hostname, port (RPROXY_HTTPS) and relative url
	- Change `172.18.0.10` by the address of the reverse proxy
- Inject gitlab server into the reverse proxy configuration
	- Add `GITLAB_IP=172.18.0.11` in `.env` file
	- Add `- "gitlab:${GITLAB_IP}"` in `extra_hosts` section of `docker-compose.yml` file
	- Add a new location in `./rproxy/nginx.conf` file
		```
        location /gitlab {
            proxy_pass          http://gitlab:80/gitlab/; # Same relative url configured in external_url
            proxy_redirect      off;
            proxy_set_header    Host                $host;
            proxy_set_header    X-Real-IP           $remote_addr;
            proxy_set_header    X-Forwarded-For     $proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Host    $server_name:443; # Same port as RPROXY_HTTPS
            proxy_set_header    X-Forwarded-Proto   $scheme;
            proxy_set_header    X-Forwarded-Ssl     on;
        }
		```

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
> docker-compose -f docker-compose.yml -f production.yml up -d
```
- Stop the server
```
> docker-compose -f docker-compose.yml -f production.yml down
```

- `https://example.com/gitlab` should respond

## Debug

- Explore the `gitlab` container
```
> docker exec -it gitlab /bin/bash
```

## Update

- Update gitlab docker image by changing the tag in `.env`
- Run `./update.sh` after an update of the gitlab configuration file `./gitlab/config/gitlab.rb`

## Restore a backup

```
./gitlab/data/backups/${D_GITLAB_BACKUP}_gitlab_backup.tar
docker exec -it gitlab chown -R git /var/opt/gitlab/backups
docker exec -it gitlab chmod -R 775 /var/opt/gitlab/backups
docker exec -it gitlab gitlab-ctl reconfigure
docker exec -it gitlab gitlab-ctl stop unicorn
docker exec -it gitlab gitlab-ctl stop sidekiq
docker exec -it gitlab gitlab-ctl status || true
docker exec -it gitlab gitlab-rake gitlab:backup:restore BACKUP=${D_GITLAB_BACKUP} --trace
docker exec -it gitlab chown -R git /var/opt/gitlab/gitlab-rails/uploads
docker exec -it gitlab gitlab-ctl reconfigure
docker exec -it gitlab gitlab-ctl restart
docker exec -it gitlab gitlab-rake gitlab:check SANITIZE=true
docker exec -it gitlab gitlab-rake cache:clear
```
