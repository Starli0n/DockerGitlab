# Run after updating ./gitlab/config/gitlab.rb

echo -e '\nStart gitlab-ctl reconfigure...'
docker exec -it gitlab gitlab-ctl reconfigure

echo -e '\nStart gitlab-ctl restart...'
docker exec -it gitlab gitlab-ctl restart
