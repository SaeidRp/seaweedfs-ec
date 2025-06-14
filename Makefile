# SeaweedFS EC Automated Docker Builder
# This Makefile builds custom SeaweedFS Docker images with configurable Erasure Coding
# Each EC configuration has its own Dockerfile that handles patching and building

# Configuration
EC_CONFIG ?= 9-3
SEAWEEDFS_VERSION ?= 3.80
DOCKER_REGISTRY = ghcr.io
GITHUB_ACTOR ?= $(shell whoami)
GITHUB_REPOSITORY ?= $(GITHUB_ACTOR)/seaweedfs_ec

# Dynamic configuration based on EC_CONFIG
DOCKERFILE = Dockerfile.ec$(subst -,,$(EC_CONFIG))
IMAGE_SUFFIX = seaweedfs-ec$(subst -,,$(EC_CONFIG))
IMAGE_NAME = $(DOCKER_REGISTRY)/$(GITHUB_REPOSITORY)/$(IMAGE_SUFFIX)

# Docker build arguments
DOCKER_BUILDX_BUILDER = multiplatform-builder
PLATFORMS = linux/amd64,linux/arm64

# Available EC configurations (auto-detected from Dockerfiles)
AVAILABLE_CONFIGS = $(patsubst Dockerfile.ec%,%,$(wildcard Dockerfile.ec*))
AVAILABLE_CONFIGS_FORMATTED = $(shell echo "$(AVAILABLE_CONFIGS)" | sed 's/\([0-9]\)\([0-9]\)/\1-\2/g')

.PHONY: help build build-multiplatform push list-configs validate-config update-version login check-latest build-all build-all-multiplatform setup-buildx

help: ## Show this help message
	@echo "SeaweedFS EC Automated Docker Builder"
	@echo "====================================="
	@echo ""
	@echo "Current Configuration:"
	@echo "  EC_CONFIG=$(EC_CONFIG)"
	@echo "  SEAWEEDFS_VERSION=$(SEAWEEDFS_VERSION)"
	@echo "  DOCKERFILE=$(DOCKERFILE)"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo ""
	@echo "Available EC Configurations:"
	@for config in $(AVAILABLE_CONFIGS_FORMATTED); do \
		echo "  - $$config"; \
	done
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'
	@echo ""
	@echo "Usage Examples:"
	@echo "  make build                           # Build EC $(EC_CONFIG) (default)"
	@echo "  make build EC_CONFIG=10-2           # Build EC 10,2"
	@echo "  make build-all                      # Build all available configurations"

list-configs: ## List all available EC configurations
	@echo "Available EC Configurations:"
	@for config in $(AVAILABLE_CONFIGS_FORMATTED); do \
		dockerfile=Dockerfile.ec$$(echo $$config | sed 's/-//g'); \
		if [ -f "$$dockerfile" ]; then \
			echo "  ✓ $$config ($$dockerfile)"; \
		fi; \
	done
	@if [ -z "$(AVAILABLE_CONFIGS)" ]; then \
		echo "  No EC configuration Dockerfiles found"; \
	fi

validate-config: ## Validate that the specified EC configuration exists
	@if [ ! -f "$(DOCKERFILE)" ]; then \
		echo "❌ Error: Dockerfile '$(DOCKERFILE)' not found"; \
		echo ""; \
		echo "Available configurations:"; \
		for config in $(AVAILABLE_CONFIGS_FORMATTED); do \
			echo "  - $$config"; \
		done; \
		echo ""; \
		echo "Usage: make <target> EC_CONFIG=<config>"; \
		echo "Or create new: make create-dockerfile EC_CONFIG=<config>"; \
		exit 1; \
	fi
	@if [ ! -f "patches/ec-$(EC_CONFIG).patch" ]; then \
		echo "❌ Error: Patch file 'patches/ec-$(EC_CONFIG).patch' not found"; \
		exit 1; \
	fi
	@echo "✅ Using EC configuration: $(EC_CONFIG)"
	@echo "✅ Dockerfile: $(DOCKERFILE)"
	@echo "✅ Patch file: patches/ec-$(EC_CONFIG).patch"
	@echo "✅ Image name: $(IMAGE_NAME)"

build: validate-config ## Build single-platform Docker image for local testing
	@echo "==> Building SeaweedFS EC $(EC_CONFIG) Docker image (local platform)"
	docker build -f $(DOCKERFILE) \
		--build-arg BRANCH=$(SEAWEEDFS_VERSION) \
		-t $(IMAGE_NAME):$(SEAWEEDFS_VERSION) \
		-t $(IMAGE_NAME):latest \
		.
	@echo "==> Build completed: $(IMAGE_NAME):$(SEAWEEDFS_VERSION)"

build-multiplatform: validate-config setup-buildx ## Build and push multi-platform Docker images
	@echo "==> Building and pushing SeaweedFS EC $(EC_CONFIG) multi-platform Docker images"
	docker buildx build \
		--builder $(DOCKER_BUILDX_BUILDER) \
		--platform $(PLATFORMS) \
		--build-arg BRANCH=$(SEAWEEDFS_VERSION) \
		-f $(DOCKERFILE) \
		-t $(IMAGE_NAME):$(SEAWEEDFS_VERSION) \
		-t $(IMAGE_NAME):latest \
		--push \
		.
	@echo "==> Multi-platform build and push completed for EC $(EC_CONFIG)"

build-all: ## Build all available EC configurations (local platform only)
	@echo "==> Building all available EC configurations"
	@for config in $(AVAILABLE_CONFIGS_FORMATTED); do \
		echo ""; \
		echo "==> Building EC $$config"; \
		$(MAKE) build EC_CONFIG=$$config || exit 1; \
	done
	@echo ""
	@echo "==> All EC configurations built successfully:"
	@for config in $(AVAILABLE_CONFIGS_FORMATTED); do \
		image_suffix=seaweedfs-ec$$(echo $$config | sed 's/-//g'); \
		echo "  ✓ $(DOCKER_REGISTRY)/$(GITHUB_REPOSITORY)/$$image_suffix:$(SEAWEEDFS_VERSION)"; \
	done

build-all-multiplatform: setup-buildx ## Build and push all available EC configurations (multi-platform)
	@echo "==> Building and pushing all available EC configurations (multi-platform)"
	@for config in $(AVAILABLE_CONFIGS_FORMATTED); do \
		echo ""; \
		echo "==> Building and pushing EC $$config"; \
		$(MAKE) build-multiplatform EC_CONFIG=$$config || exit 1; \
	done
	@echo ""
	@echo "==> All EC configurations built and pushed successfully"

setup-buildx: ## Setup Docker Buildx for multi-platform builds
	@echo "==> Setting up Docker Buildx"
	@if ! docker buildx ls | grep -q $(DOCKER_BUILDX_BUILDER); then \
		docker buildx create --name $(DOCKER_BUILDX_BUILDER) --driver docker-container --bootstrap; \
	fi
	docker buildx use $(DOCKER_BUILDX_BUILDER)

push: ## Push Docker images to registry (requires build first)
	@echo "==> Pushing SeaweedFS EC $(EC_CONFIG) Docker images"
	docker push $(IMAGE_NAME):$(SEAWEEDFS_VERSION)
	docker push $(IMAGE_NAME):latest
	@echo "==> Push completed for EC $(EC_CONFIG)"

clean: ## Clean up build artifacts and Docker resources
	@echo "==> Cleaning up build artifacts"
	@echo "==> Pruning Docker build cache"
	@docker builder prune -f > /dev/null 2>&1 || true
	@echo "==> Cleanup completed"

update-version: ## Update SeaweedFS version (usage: make update-version SEAWEEDFS_VERSION=3.82)
	@if [ -z "$(SEAWEEDFS_VERSION)" ]; then \
		echo "Error: SEAWEEDFS_VERSION is required"; \
		echo "Usage: make update-version SEAWEEDFS_VERSION=3.82"; \
		exit 1; \
	fi
	@echo "==> Updating SeaweedFS version to $(SEAWEEDFS_VERSION)"
	sed -i.bak 's/^SEAWEEDFS_VERSION ?= .*/SEAWEEDFS_VERSION ?= $(SEAWEEDFS_VERSION)/' Makefile
	rm -f Makefile.bak
	@echo "==> Version updated to $(SEAWEEDFS_VERSION)"

login: ## Login to GitHub Container Registry
	@echo "==> Logging into GitHub Container Registry"
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "Error: GITHUB_TOKEN environment variable is required"; \
		echo "Export your GitHub Personal Access Token: export GITHUB_TOKEN=your_token"; \
		exit 1; \
	fi
	echo "$(GITHUB_TOKEN)" | docker login $(DOCKER_REGISTRY) -u $(GITHUB_ACTOR) --password-stdin
	@echo "==> Login successful"

check-latest: ## Check for latest SeaweedFS version
	@echo "==> Checking for latest SeaweedFS version"
	@LATEST=$$(curl -s https://api.github.com/repos/seaweedfs/seaweedfs/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'); \
	echo "Latest version: $$LATEST"; \
	echo "Current version: $(SEAWEEDFS_VERSION)"; \
	if [ "$$LATEST" != "$(SEAWEEDFS_VERSION)" ]; then \
		echo "New version available: $$LATEST"; \
		echo "Run: make update-version SEAWEEDFS_VERSION=$$LATEST"; \
	else \
		echo "Already using the latest version"; \
	fi