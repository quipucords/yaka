# Yet Another Konflux Attempt

This is a playground to prototype, reproduce issues in a smaller scale (and attempt to solve them)
in a more controlled environment.

Currently it is very painful to build cryptography from source. This repo works aims to serve
as a guide on how to do it with cachi2/konflux.

In order to ensure cryptography was successfully built the image will decrypt a message.

## Installation
```
make install
```
`podman` and `uv` are required


## Generating the lockfiles

```
make lock-all
```

## Non-hermetic build

```
podman build -t yaka-simple .
```

Make sure it is working by running

```
podman run -it localhost/yaka-simple:latest
```

## Hermetic build
Building this image without network access can be done locally thanks to 
[cachi2-playground](https://github.com/brunoapimentel/cachi2-playground) script.

You will also need a `input.env` file like the following
```.env
GIT_REPO="https://github.com/quipucords/yaka"
REF="main"
PREFETCH_INPUT='[{"type": "pip", "path": "lockfiles"}, {"type": "rpm", "path": "lockfiles"}, {"type": "generic", "path": "lockfiles"}]'
CACHI2_IMAGE="quay.io/konflux-ci/hermeto:latest"
CONTAINERFILE_PATH="./Containerfile"
OUTPUT_IMAGE="localhost/yaka-hermetic:latest"
```

Then run `./clone-and-build.sh`.
mamao
