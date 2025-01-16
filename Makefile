UBI_IMAGE=registry.access.redhat.com/ubi9
UBI_MINIMAL_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal
RPM_LOCKFILE_IMAGE=localhost/rpm-lockfile-prototype


update-ubi-repo:
	podman pull $(UBI_MINIMAL_IMAGE)
	podman run -it $(UBI_MINIMAL_IMAGE) cat /etc/yum.repos.d/ubi.repo > ubi.repo

setup-rpm-lockfile:
	podman pull $(UBI_IMAGE)
	curl https://raw.githubusercontent.com/konflux-ci/rpm-lockfile-prototype/refs/heads/main/Containerfile | \
		podman build -t $(RPM_LOCKFILE_IMAGE) \
		--build-arg BASE_IMAGE=$(UBI_IMAGE) -

lock-rpms: setup-rpm-lockfile update-ubi-repo
	podman run --rm -v ${PWD}:/workdir:Z $(RPM_LOCKFILE_IMAGE):latest \
		--image $(UBI_MINIMAL_IMAGE) \
		--outfile=/workdir/rpms.lock.yaml \
		/workdir/rpms.in.yaml
