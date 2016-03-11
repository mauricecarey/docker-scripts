#!/bin/bash

check_env() {
    echo "Using $1:" ${!1:?"Need to set: $1"}
}

check_set_default() {
    eval "${1}=${!1:-$2}"
    echo "Using $1:" ${!1}
}

# Check that env vars are defined.
check_set_default "DOCKERFILE" "Dockerfile"
check_env "MAINTAINER"
check_env "FAT_JAR_PATH"
check_env "FAT_JAR_NAME"
check_set_default "PORT" "8080"

cat<<EOF > ${DOCKERFILE}
FROM mmcarey/ubuntu-java:latest
MAINTAINER "${MAINTAINER}"

WORKDIR /app
ADD ${FAT_JAR_PATH}/${FAT_JAR_NAME} /app/${FAT_JAR_NAME}

EXPOSE ${PORT}
CMD ["/usr/bin/java", "-jar", "/app/${FAT_JAR_NAME}"]
EOF
