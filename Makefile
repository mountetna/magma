include ../make-base/stubs.mk

export MAGMA_PROJECTS=$(shell cat config.yml | grep ':project_path:' | sed -e 's/.*:project_path:\s*//g')
.projects-mark: config.yml
	echo $(MAGMA_PROJECTS)
	for project in $(MAGMA_PROJECTS); do \
		test -e $$project && continue; \
		git clone git@github.com:mountetna/magma-$$(basename $$project).git $$project; \
	  done
	@ touch .projects-mark

docker-ready:: .projects-mark
	@ true

migrate::
	@ docker-compose run --rm ${app_service_name} ./bin/${app_name} migrate
	@ docker-compose run --rm ${app_service_name} ./bin/${app_name} global_migrate
	@ docker-compose run -e ${app_name_capitalized}_ENV=test --rm ${app_service_name} ./bin/${app_name} migrate
	@ docker-compose run -e ${app_name_capitalized}_ENV=test --rm ${app_service_name} ./bin/${app_name} global_migrate

app_name=magma
include ../make-base/etna-ruby.mk
include ../make-base/docker-compose.mk

