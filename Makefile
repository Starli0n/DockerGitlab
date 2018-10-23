-include .env
export $(shell sed 's/=.*//' .env)

export GITLAB_HOSTNAME=${GITLAB_CONTAINER}.${NGINX_HOSTNAME}
export GITLAB_HTTP_URL=http://${GITLAB_HOSTNAME}:${NGINX_PROXY_HTTP}
export GITLAB_HTTPS_URL=https://${GITLAB_HOSTNAME}:${NGINX_PROXY_HTTPS}
export GITLAB_EXTERNAL_URL=${GITLAB_HTTPS_URL}

.PHONY: env_var
env_var: # Print environnement variables
	@cat .env
	@echo
	@echo GITLAB_HOSTNAME=${GITLAB_HOSTNAME}
	@echo GITLAB_HTTP_URL=${GITLAB_HTTP_URL}
	@echo GITLAB_HTTPS_URL=${GITLAB_HTTPS_URL}
	@echo GITLAB_EXTERNAL_URL=${GITLAB_EXTERNAL_URL}

.PHONY: initialize
initialize: init
	cp -n .env.default .env
	chmod +x update.sh
	chmod +x container-status.sh
	mkdir -p .ssh
	ssh-keygen -t rsa -b 4096 -C "${GITLAB_CONTAINER}@no-reply.com" -f "$$PWD/.ssh/id_${GITLAB_CONTAINER}_rsa"

.PHONY: init
init:
	mkdir -p gitlab/{config,logs,data}
	chmod -R 777 gitlab/{config,logs,data}

.PHONY: erase
erase:
	rm -rf gitlab

.PHONY: pull
pull: # Pull the docker image
	docker pull gitlab/gitlab-ce:${TAG}

.PHONY: config
config: # Show docker-compose configuration
	docker-compose -f docker-compose.yml config

.PHONY: up
up: # Start containers and services
	docker-compose -f docker-compose.yml up -d

.PHONY: down
down: # Stop containers and services
	docker-compose -f docker-compose.yml down

.PHONY: start
start: # Start containers
	docker-compose -f docker-compose.yml start

.PHONY: stop
stop: # Stop containers
	docker-compose -f docker-compose.yml stop

.PHONY: restart
restart: # Restart container
	docker-compose -f docker-compose.yml restart

.PHONY: delete
delete: down erase

.PHONY: mount
mount: init up perm ctl-reconfigure

.PHONY: reset
reset: delete mount

.PHONY: update
update: # Update docker image and restart the container
	make pull
	make backup-create
	make stop
	docker rm ${GITLAB_CONTAINER}
	make up

.PHONY: logs
logs: # Tail all logs; press Ctrl-C to exit
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl tail

.PHONY: logs-rails
logs-rails: # Drill down to a sub-directory of /var/log/gitlab
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl tail gitlab-rails

.PHONY: logs-nginx
logs-nginx: # Drill down to an individual file
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl tail nginx/gitlab_error.log

.PHONY: shell
shell: # Open a shell on a started container
	docker exec -it ${GITLAB_CONTAINER} /bin/bash

.PHONY: status
status: # Check the status of the container (from starting to healthy)
	@./container-status.sh ${GITLAB_CONTAINER}

.PHONY: curl
curl: # Test that the container is up with curl
	docker exec -it ${GITLAB_CONTAINER} curl 127.0.0.1; echo -e "\n"
	docker exec -it ${GITLAB_CONTAINER} curl 127.0.0.1:8080; echo -e "\n"
	docker exec -it ${GITLAB_CONTAINER} curl 127.0.0.1:443 -k; echo -e "\n"

.PHONY: url
url:
	@echo ${GITLAB_EXTERNAL_URL}

.PHONY: perm
perm:
	docker exec -it ${GITLAB_CONTAINER} update-permissions

.PHONY: ctl-reconfigure
ctl-reconfigure:
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl reconfigure

.PHONY: ctl-restart
ctl-restart:
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl restart

.PHONY: backup-create
backup-create:
	echo -e "Begin at `date`\n">backup.log
	docker exec -t ${GITLAB_CONTAINER} gitlab-rake gitlab:backup:create>>backup.log 2>&1
	echo -e "\nEnd at `date`">>backup.log

.PHONY: backup-restore
backup-restore: # ./gitlab/data/backups/${GITLAB_BACKUP}_gitlab_backup.tar
	docker exec -it ${GITLAB_CONTAINER} chown -R git /var/opt/gitlab/backups
	docker exec -it ${GITLAB_CONTAINER} chmod -R 775 /var/opt/gitlab/backups
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl reconfigure
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl stop unicorn
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl stop sidekiq
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl status || true
	docker exec -it ${GITLAB_CONTAINER} gitlab-rake gitlab:backup:restore BACKUP=${GITLAB_BACKUP} --trace
	docker exec -it ${GITLAB_CONTAINER} chown -R git /var/opt/gitlab/gitlab-rails/uploads
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl reconfigure
	docker exec -it ${GITLAB_CONTAINER} gitlab-ctl restart
	docker exec -it ${GITLAB_CONTAINER} gitlab-rake gitlab:check SANITIZE=true
	docker exec -it ${GITLAB_CONTAINER} gitlab-rake cache:clear

.PHONY: backup-rsync
backup-rsync:
	rsync -a -e "ssh -i .ssh/id_gitlab_rsa" gitlab/data/backups/ ${BACKUP_SRV_USR}@${BACKUP_SRV_HOST}:${BACKUP_SRV_PATH}

.PHONY: backup-create-rsync
backup-create-rsync: backup-create backup-rsync

.PHONY: backup-srv-shell
backup-srv-shell:
	ssh ${BACKUP_SRV_USR}@${BACKUP_SRV_HOST} -i ".ssh/id_gitlab_rsa"
