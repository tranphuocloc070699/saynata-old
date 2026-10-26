# One entry point for every part. Each part has its own Makefile with a `check` target.
#   make up           start local services (Postgres) in Docker
#   make check        lint + types + tests for every part
#   make check-web    only one part (backend, web, python, ios)
PARTS := $(patsubst %/Makefile,%,$(wildcard */Makefile))

.PHONY: up down check doctor $(addprefix check-,$(PARTS))

up:
	docker compose up -d --wait

down:
	docker compose down

doctor:
	scripts/doctor.sh

check: $(addprefix check-,$(PARTS))

$(addprefix check-,$(PARTS)): check-%:
	$(MAKE) -C $* check
