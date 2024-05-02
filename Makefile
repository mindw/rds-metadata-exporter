# Define Python environment variables
PYTHON_INTERPRETER := python3
POETRY := $(PYTHON_INTERPRETER) -m poetry

# Define Docker environment variables
DOCKER := docker
DOCKER_IMAGE_NAME := rds-metadata-exporter
DOCKER_CONTAINER_NAME := rds-metadata-exporter

# AWS credentials file path
AWS_CONF_DIR := /home/exporter/.aws

# Target to install project dependencies using Poetry
install:
	$(POETRY) install

# Target to build the Docker image
docker-build:
	$(DOCKER) build -t $(DOCKER_IMAGE_NAME) .

# Target to run the Docker container
docker-run:
	$(DOCKER) run -it --rm \
		--name $(DOCKER_CONTAINER_NAME) \
		-p 8000:8000 \
		--volume ${HOME}/.aws:/app/.aws:ro \
		$(DOCKER_IMAGE_NAME) ${AWS_REGION} ${RDS_SERVER}

#		--env AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
#		--env AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \

# Target to clean up unused Docker resources
docker-clean:
	$(DOCKER) system prune -af

# Help target
help:
	@echo "Available targets:"
	@echo "  install           : Install project dependencies using Poetry"
	@echo "  docker-build      : Build the Docker image"
	@echo "  docker-run        : Run the Docker container"
	@echo "  docker-clean      : Clean up unused Docker resources"
	@echo "  help              : Show this help message"
