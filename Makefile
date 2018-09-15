-include .env
export $(shell sed 's/=.*//' .env)

.PHONY: env_var
env_var: # Print environnement variables
	@cat .env

.PHONY: init
init: # Show docker-compose configuration
	chmod +x update.sh
	chmod +x container-status.sh

.PHONY: config
config: # Show docker-compose configuration
	docker-compose -f docker-compose.yml -f production.yml config

.PHONY: up
up: # Start containers and services
	docker-compose -f docker-compose.yml -f production.yml up -d

.PHONY: down
down: # Stop containers and services
	docker-compose -f docker-compose.yml -f production.yml down

.PHONY: start
start: # Start containers
	docker-compose -f docker-compose.yml -f production.yml start

.PHONY: stop
stop: # Stop containers
	docker-compose -f docker-compose.yml -f production.yml stop

.PHONY: restart
restart: # Restart container
	docker-compose -f docker-compose.yml -f production.yml restart

.PHONY: update
update: gitlab-stop gitlab-pull gitlab-start # Update docker image and restart the container

.PHONY: logs
logs: # Tail all logs; press Ctrl-C to exit
	docker exec -it gitlab gitlab-ctl tail

.PHONY: logs-rails
logs-rails: # Drill down to a sub-directory of /var/log/gitlab
	docker exec -it gitlab gitlab-ctl tail gitlab-rails

.PHONY: logs-nginx
logs-nginx: # Drill down to an individual file
	docker exec -it gitlab gitlab-ctl tail nginx/gitlab_error.log

.PHONY: shell
shell: # Open a shell on a started container
	docker exec -it gitlab /bin/bash

.PHONY: status
status: # Check the status of the container (from starting to healthy)
	@./container-status.sh gitlab

.PHONY: curl
curl: # Test that the container is up with curl
	docker exec -it gitlab curl 127.0.0.1; echo -e "\n"
	docker exec -it gitlab curl 127.0.0.1:8080; echo -e "\n"
	docker exec -it gitlab curl 127.0.0.1:443 -k; echo -e "\n"

.PHONY: perm
perm:
	docker exec -it gitlab update-permissions

.PHONY: ctl-reconfigure
ctl-reconfigure:
	docker exec -it gitlab gitlab-ctl reconfigure

.PHONY: ctl-restart
ctl-restart:
	docker exec -it gitlab gitlab-ctl restart

.PHONY: backup-create
backup-create:
	echo -e "Begin at `date`\n">backup.log
	docker exec -t gitlab gitlab-rake gitlab:backup:create>>backup.log 2>&1
	echo -e "\nEnd at `date`">>backup.log

.PHONY: backup-restore
backup-restore: # ./gitlab/data/backups/${D_GITLAB_BACKUP}_gitlab_backup.tar
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
