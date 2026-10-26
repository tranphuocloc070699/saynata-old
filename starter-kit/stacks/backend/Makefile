.PHONY: check test format run
check:            ## format check + all tests (what CI runs)
	./mvnw -B verify
test:             ## one class: make test T=NoteControllerTest
	./mvnw -B test $(if $(T),-Dtest='$(T)*')
format:
	./mvnw -B -q spotless:apply
run:
	./mvnw -B spring-boot:run
