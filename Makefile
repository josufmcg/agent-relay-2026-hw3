IMAGE ?= agent-relay:local
PORT ?= 8000

.PHONY: build run compose-up compose-down

build:
	docker build -t $(IMAGE) .

run: compose-up

compose-up:
	PORT=$(PORT) docker compose up --build

compose-down:
	docker compose down