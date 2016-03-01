#!/bin/bash

test_quit() {
    if [ "$1" -ne 0 ]; then
        test "$2" && echo "$2";
        exit $1;
    fi
}

check_env() {
    echo "Using $1:" ${!1:?"Need to set: $1"}
}

# Check that AWS_REGION is defined.
check_env "AWS_REGION"

# Check that AWS_ACCOUNT_NUM is defined.
check_env "AWS_ACCOUNT_NUM"

# Check that REPO_NAME is defined.
check_env "REPO_NAME"

# Check that IMAGE_VERSION is defined.
check_env "IMAGE_VERSION"

# Check that DOCKER_FILE is defined.
check_env "DOCKER_FILE"

OUTPUT=/dev/null

# Check that repository exists and create if not.
aws --region $AWS_REGION ecr describe-repositories --repository-names $REPO_NAME &> $OUTPUT # if non-zero exit status then it doesn't exist.
REPO_NOT_EXIST=$?
if [ $REPO_NOT_EXIST -eq 0 ]; then
    echo "Using existing repo."
else
    aws --region $AWS_REGION ecr create-repository --repository-name $REPO_NAME;
    echo "Created new repo: $REPO_NAME"
fi

# Docker login
$(aws ecr get-login --region $AWS_REGION)

# Pull the latest from the repo if we didn't just create it.
if [ $REPO_NOT_EXIST -eq 0 ]; then
    docker pull $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest > $OUTPUT;
    test_quit $? "ERROR: Could not pull latest image from repo $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest"
    echo "Pulled image from: $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest"
    # Tag this as the old repo version.
    docker tag $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest $REPO_NAME:old-repo > $OUTPUT
    test_quit $? "ERROR: Could not tag image $REPO_NAME:old-repo"
fi

# Build the docker image.
docker build --tag $REPO_NAME --file=$DOCKER_FILE . > $OUTPUT
test_quit $? "ERROR: Could not build image."
echo "Built: $REPO_NAME"

# Tag the new image as the latest in remote repo.
docker tag $REPO_NAME:latest $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest > $OUTPUT
test_quit $? "ERROR: Could not tag image $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest"

# Tag the version number.
docker tag $REPO_NAME:latest $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_VERSION > $OUTPUT
test_quit $? "ERROR: Could not tag image $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_VERSION"

# Push the new version.
docker push $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_VERSION > $OUTPUT
test_quit $? "ERROR: Could not push image $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_VERSION"
echo "Pushed: $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_VERSION"

# Push the latest tag to repo.
docker push $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest > $OUTPUT
test_quit $? "ERROR: Could not push image $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest"
echo "Pushed tag: $AWS_ACCOUNT_NUM.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest"

# Clean up our tags.
if [ $REPO_NOT_EXIST -eq 0 ]; then
    docker rmi $REPO_NAME:old-repo > $OUTPUT
    test_quit $? "ERROR: Could not remove tag $REPO_NAME:old-repo"
fi

echo "Finished building $REPO_NAME:$IMAGE_VERSION"
