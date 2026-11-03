-include .env

BASE_DIR ?= .
TZ ?= UTC
ALICE_PORT ?= 8080
ALICE_PUBLISH ?= 127.0.0.1
ALICE_FRIGATE_DIR ?= data/frigate
ALICE_FRIGATE_REMOTE ?=
ALICE_MEM_LIMIT ?=
ALICE_CPU_LIMIT ?=

image := localhost/alice:local
base := $(abspath $(BASE_DIR))
frigate := $(abspath $(ALICE_FRIGATE_DIR))

.PHONY: build mount up down clean logs

build:
	podman build --format docker --target production --tag $(image) .

mount:
ifneq ($(ALICE_FRIGATE_REMOTE),)
	scripts/mount-frigate.sh $(ALICE_FRIGATE_REMOTE)
endif

# Keep-id leaves files owned by the invoking user.
up: build mount
	podman run --detach --replace --name alice \
		--init \
		--userns keep-id \
		--cap-drop all \
		--security-opt no-new-privileges \
		--publish $(ALICE_PUBLISH):$(ALICE_PORT):$(ALICE_PORT) \
		--env TZ=$(TZ) \
		--env ALICE_PORT=$(ALICE_PORT) \
		--volume $(base)/config:/app/config \
		--volume $(base)/data/datasets:/app/datasets \
		--volume $(base)/data/models:/app/models \
		--volume $(frigate)/data/clips:/app/clips:ro \
		--volume $(frigate)/data/exports:/app/exports:ro \
		--volume $(frigate)/config:/app/frigate:ro \
		$(if $(ALICE_MEM_LIMIT),--memory $(ALICE_MEM_LIMIT)) \
		$(if $(ALICE_CPU_LIMIT),--cpus $(ALICE_CPU_LIMIT)) \
		$(image)

down:
	podman rm --force --ignore alice

# The container must be gone first it holds the mount open.
clean: down
	@if mountpoint -q data/frigate; then \
		fusermount3 -u data/frigate && echo "Unmounted data/frigate"; \
	else \
		echo "data/frigate is not mounted"; \
	fi

logs:
	podman logs --follow alice
