IMAGE ?= agent-relay:local
PORT ?= 8000
KIND_CLUSTER ?= kind
K8S_NAMESPACE ?= agent-relay
KIND_BIN ?= $(shell command -v kind 2>/dev/null || printf '%s' "$(HOME)/go/bin/kind")

.PHONY: build run compose-up compose-down kind-load k8s-deploy k8s-down

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
