UBI_IMAGE=registry.access.redhat.com/ubi9
UBI_MINIMAL_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal
RPM_LOCKFILE_IMAGE=localhost/rpm-lockfile-prototype


update-ubi-repo:
	podman pull $(UBI_MINIMAL_IMAGE)
	podman run -it $(UBI_MINIMAL_IMAGE) cat /etc/yum.repos.d/ubi.repo > lockfiles/ubi.repo

setup-rpm-lockfile: update-ubi-repo
	podman pull $(UBI_IMAGE)
	curl https://raw.githubusercontent.com/konflux-ci/rpm-lockfile-prototype/refs/heads/main/Containerfile | \
		podman build -t $(RPM_LOCKFILE_IMAGE) \
		--build-arg BASE_IMAGE=$(UBI_IMAGE) -

install: update-ubi-repo setup-rpm-lockfile
	uv sync

lock-rpms: update-ubi-repo
	podman run --rm -v ${PWD}/lockfiles:/workdir:Z $(RPM_LOCKFILE_IMAGE):latest \
		--image $(UBI_MINIMAL_IMAGE) \
		--outfile=/workdir/rpms.lock.yaml \
		/workdir/rpms.in.yaml

lock-pip:
	uv export -o lockfiles/requirements.txt --no-dev --frozen
	uv run pybuild-deps compile lockfiles/requirements.txt --output-file=lockfiles/requirements-build.txt

lock-cargo:
	uv run pybuild-deps rusted-lock \
		lockfiles/requirements.txt lockfiles/requirements-build.txt \
		-o lockfiles/artifacts.lock.yaml

lock-all: lock-pip lock-rpms lock-cargo
