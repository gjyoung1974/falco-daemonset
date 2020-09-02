all:  falcods
FALCODS := gcr.io/pm-registry/falcods:latest
FALCODS_DEV := gjyoung1974/falcods:latest
FALCO := gcr.io/pm-registry/falco:latest

falcods:
	docker build --pull --rm --label org.label-schema.vcs-url=https://github.com/acme/k8s.git  -f "Dockerfile" --tag $(FALCODS) "."

dev:
	docker build --pull --rm --label org.label-schema.vcs-url=https://github.com/acme/k8s.git  -f "Dockerfile.dev" --tag $(FALCODS_DEV) "."

falco_base:
	docker build --pull --rm --label org.label-schema.vcs-url=https://github.com/acme/k8s.git -f "Dockerfile.falco" --tag $(FALCO) "."

push:
	docker push $(FALCODS)

push_dev:
	docker push $(FALCODS_DEV)

push_falco_base:
	docker push $(FALCO)
