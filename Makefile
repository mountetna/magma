include ../make-base/stubs.mk
include ../make-base/docker-compose.mk
include ../make-base/etna-ruby.mk


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

