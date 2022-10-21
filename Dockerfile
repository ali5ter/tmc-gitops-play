FROM ubuntu:bionic AS builder
RUN apt-get update && apt-get install -y curl
WORKDIR /root
RUN curl https://tmc-cli.s3-us-west-2.amazonaws.com/tmc/0.5.1-1dfe19c8/linux/x64/tmc -o /root/tmc
RUN chmod +x /root/tmc

FROM ubuntu:20.04
COPY --from=builder /root/tmc /usr/local/bin/tmc
RUN chmod +x /usr/local/bin/tmc

RUN apt-get update && apt-get install -y jq git curl && curl -L --output /usr/local/bin/yq  https://github.com/mikefarah/yq/releases/download/v4.48.2/yq_linux_amd64 && chmod +x  /usr/local/bin/yq

WORKDIR /usr/src/app

ADD apply.sh /usr/src/app
ADD cluster_patch_yaml.sh /usr/src/app
RUN chmod +x /usr/src/app/*

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]