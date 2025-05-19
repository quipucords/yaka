PYTHON		= $(shell uv run which python 2>/dev/null || which python)
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  DEFAULT_CACHE_DIR := $(HOME)/Library/Caches
  # macOS/Darwin's built-in `sed` and `date` are BSD-style and incompatible with Linux/GNU-style arguments.
  # However, macOS users can install GNU sed as `gsed` and GNU date as `gdate` using Homebrew.
  ifneq ($(shell command -v gsed),)
    SED := gsed
  else
    $(info "Warning: gsed may be required on macOS, but it is not installed.")
    $(info "Please run 'brew install gnu-sed' to install it.")
    SED := sed # Fall back to default sed for now
  endif
  ifneq ($(shell command -v gdate),)
    DATE := gdate
  else
    $(info "Warning: gdate may be required on macOS, but it is not installed.")
    $(info "Please run 'brew install coreutils' to install it.")
    DATE := date # Fall back to default date for now
  endif
else
  DEFAULT_CACHE_DIR := $(HOME)/.cache
  SED := sed
  DATE := date
endif
CACHE_DIR := $(shell [ -n "$(XDG_CACHE_HOME)" ] && echo "$(XDG_CACHE_HOME)" || echo "$(DEFAULT_CACHE_DIR)")
TOPDIR = $(shell pwd)

UBI_VERSION=9
UBI_IMAGE=registry.access.redhat.com/ubi$(UBI_VERSION)
UBI_MINIMAL_IMAGE=registry.access.redhat.com/ubi$(UBI_VERSION)/ubi-minimal
RPM_LOCKFILE_IMAGE=localhost/rpm-lockfile-prototype

help:
	@echo "Please use \`make <target>' where <target> is one of:"
	@echo "  help                          to show this message"
	@echo "  lock-requirements             to lock all python dependencies"
	@echo "  lock-rpms  		           to lock all dnf dependencies"
	@echo "  update-requirements           to update all python dependencies"
	@echo "  update-lockfiles		       update all 'lockfiles'"

lock-requirements: lock-main-requirements lock-build-requirements

lock-main-requirements:
	uv lock
	uv export --no-emit-project --no-dev --frozen --no-hashes -o lockfiles/requirements.txt

lock-build-requirements:
	uv run pybuild-deps compile lockfiles/requirements.txt -o lockfiles/requirements-build.txt

update-requirements:
	uv lock --upgrade
	$(MAKE) lock-requirements

# prepare rpm-lockfile-prototype tool to lock our rpms
setup-rpm-lockfile:
	latest_digest=$$(skopeo inspect --raw "docker://$(UBI_IMAGE):latest" | sha256sum | cut -d ' ' -f1); \
	curl https://raw.githubusercontent.com/konflux-ci/rpm-lockfile-prototype/refs/heads/main/Containerfile | \
		podman build -t $(RPM_LOCKFILE_IMAGE) \
		--build-arg "BASE_IMAGE=$(UBI_IMAGE)@sha256:$${latest_digest}" -

setup-rpm-lockfile-if-needed:
ifneq ($(shell podman image exists $(RPM_LOCKFILE_IMAGE) >/dev/null 2>&1; echo $$?), 0)
	$(MAKE) setup-rpm-lockfile
else
	$(eval image_created_at=$(shell $(DATE) -d $$(podman inspect --format '{{json .Created}}' $(RPM_LOCKFILE_IMAGE) | tr -d '"') +"%s"))
	$(eval 36h_ago=$(shell $(DATE) -d "36 hours ago" +"%s"))
	# recreate the rpm-lockfile container if it is "old"
	@if [ "$(image_created_at)" -lt "$(36h_ago)" ]; then \
		$(MAKE) setup-rpm-lockfile; \
	fi
endif

# update rpm locks
lock-rpms: setup-rpm-lockfile-if-needed
	# the last layer will be considered the base image here; 
	$(eval BASE_IMAGE=$(shell grep '^FROM ' Containerfile | tail -n1 | cut -d" " -f2))
	# extract ubi.repo from BASE_IMAGE
	# lots of sed substitutions requred because ubi images don't have the ubi.repo formatted in the way 
	# the EC checks expect
	# https://github.com/release-engineering/rhtap-ec-policy/blob/main/data/known_rpm_repositories.yml
	# more about this on downstream konflux docs https://url.corp.redhat.com/d54f834
	podman run -it --rm "$(BASE_IMAGE)" cat /etc/yum.repos.d/ubi.repo | \
		$(SED) 's/ubi-$(UBI_VERSION)-codeready-builder-\([[:alnum:]-]*rpms\)/codeready-builder-for-ubi-$(UBI_VERSION)-$$basearch-\1/g' | \
		$(SED) 's/ubi-$(UBI_VERSION)-\([[:alnum:]-]*rpms\)/ubi-$(UBI_VERSION)-for-$$basearch-\1/g' | \
		$(SED) 's/\r$$//' > lockfiles/ubi.repo
	# finally, update the rpm locks
	# RPMDB_CACHE => rpm-lockfile-prototype has an undocumented cache
	# https://github.com/konflux-ci/rpm-lockfile-prototype/blob/283ee2cd7938a2142d8ac98de33ba0d0e3ac146f/rpm_lockfile/utils.py#L18C1-L18C11
	RPMDB_CACHE_PATH="$(CACHE_DIR)/rpm-lockfile-prototype"; \
	mkdir -p "$${RPMDB_CACHE_PATH}"; \
	podman run -w /workdir --rm \
		-v $(TOPDIR):/workdir:Z \
		-v "$${RPMDB_CACHE_PATH}:/root/.cache/rpm-lockfile-prototype:Z" \
		$(RPM_LOCKFILE_IMAGE):latest \
		--image $(BASE_IMAGE) \
		--outfile=/workdir/lockfiles/rpms.lock.yaml \
		rpms.in.yaml

# update image digest
.PHONY: lock-baseimages
lock-baseimages:
	separator="================================================================"; \
	baseimages=($$(grep '^FROM ' Containerfile | sed 's/FROM\s*\(.*\)@.*/\1/g' | sort -u)); \
	for image in $${baseimages[@]}; do \
		echo "$${separator}"; \
		echo "updating $${image}..."; \
		# escape "/" for use in $(SED) later \
		escaped_img=$$(echo $${image} | $(SED) 's/\//\\\//g') ;\
		# extract the image digest \
		updated_sha=$$(skopeo inspect --raw "docker://$${image}:latest" | sha256sum | cut -d ' ' -f1); \
		# update Containerfile with the new digest \
		$(SED) -i "s/^\(FROM $${escaped_img}@sha256:\)[[:alnum:]]*/\1$${updated_sha}/g" Containerfile; \
	done; \
	echo "$${separator}"

update-konflux-pipeline:
	@if which pipeline-patcher > /dev/null 2>&1; then \
		pipeline-patcher bump-task-refs .; \
	else \
		echo "'pipeline-patcher' not found in PATH; Refer to https://github.com/simonbaird/konflux-pipeline-patcher/blob/main/README.md."; \
		exit 1; \
	fi

update-lockfiles: lock-baseimages lock-rpms update-requirements update-konflux-pipeline
