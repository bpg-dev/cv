.PHONY: hugo run build clean docker-build docker-run help

# Variables
IMAGE_NAME ?= cv-site
IMAGE_TAG ?= latest
CONTAINER_NAME ?= cv-site
PORT ?= 8080

# Default target
.DEFAULT_GOAL := help

## hugo: Build the Hugo site locally
hugo:
	@echo "Building Hugo site..."
	hugo --minify --gc
	@echo "Site built in ./public directory"

## run: Build and run the site in Docker
run: docker-build docker-run

## docker-build: Build the Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "Docker image built: $(IMAGE_NAME):$(IMAGE_TAG)"

## docker-run: Run the Docker container
docker-run:
	@echo "Running Docker container on port $(PORT)..."
	@docker stop $(CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p $(PORT):80 \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "Container running at http://localhost:$(PORT)"
	@echo "Stop with: docker stop $(CONTAINER_NAME)"

## clean: Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf public/
	rm -rf resources/_gen/
	@echo "Clean complete"

## docker-clean: Stop and remove Docker container
docker-clean:
	@echo "Stopping and removing Docker container..."
	@docker stop $(CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(CONTAINER_NAME) 2>/dev/null || true
	@echo "Docker container cleaned"

## help: Show this help message
help:
	@echo "Available targets:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

