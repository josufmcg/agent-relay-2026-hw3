IMAGE ?= agent-relay:local
PORT ?= 8000
KIND_CLUSTER ?= kind
K8S_NAMESPACE ?= agent-relay
KIND_BIN ?= $(shell command -v kind 2>/dev/null || printf '%s' "$(HOME)/go/bin/kind")
ACT_BIN ?= $(shell command -v act 2>/dev/null || printf '%s' "$(HOME)/go/bin/act")
ACT_PLATFORM ?= catthehacker/ubuntu:act-latest

.PHONY: build run compose-up compose-down kind-load k8s-deploy k8s-down port-forward ci-test ci-deploy ci

build:
	docker build -t $(IMAGE) .

run: compose-up

compose-up:
	PORT=$(PORT) docker compose up --build

compose-down:
	docker compose down

kind-load: build
	@test -x "$(KIND_BIN)" || (echo "kind was not found; install it or set KIND_BIN=/path/to/kind" >&2; exit 1)
	"$(KIND_BIN)" load docker-image $(IMAGE) --name $(KIND_CLUSTER)

k8s-deploy: kind-load
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/postgres.yaml
	kubectl apply -f k8s/agent-relay.yaml
	kubectl rollout status deployment/postgres -n $(K8S_NAMESPACE) --timeout=120s
	kubectl rollout status deployment/agent-relay -n $(K8S_NAMESPACE) --timeout=120s

k8s-down:
	kubectl delete namespace $(K8S_NAMESPACE)

port-forward:
	kubectl port-forward -n $(K8S_NAMESPACE) deployment/agent-relay $(PORT):8000

ci-test:
	@test -x "$(ACT_BIN)" || (echo "act was not found; install it or set ACT_BIN=/path/to/act" >&2; exit 1)
	"$(ACT_BIN)" -j test -P ubuntu-latest=$(ACT_PLATFORM)

ci-deploy:
	@test -x "$(ACT_BIN)" || (echo "act was not found; install it or set ACT_BIN=/path/to/act" >&2; exit 1)
	"$(ACT_BIN)" -j build-and-deploy -P ubuntu-latest=$(ACT_PLATFORM)

ci: ci-deploy

fix-cluster-config:
	kind export kubeconfig --name kind
	kubectl config use-context kind-kind
