FROM registry.access.redhat.com/ubi9/ubi-minimal

RUN microdnf install -y python-pip
RUN pip install --user cryptography
