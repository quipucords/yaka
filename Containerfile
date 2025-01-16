FROM registry.access.redhat.com/ubi9/ubi-minimal

RUN microdnf install -y python3.12-pip
RUN pip install -r requirements.txt
