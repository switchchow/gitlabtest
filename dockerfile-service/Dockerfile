#version 0110
FROM centos:latest
MAINTAINER zws
ADD go1.17.6.linux-amd64.tar.gz /usr/local
CMD ["export","PATH=$PATH:/usr/local/go/bin"]
ADD service-a-main.tar.gz /usr/local
ENTRYPOINT ["/usr/local/service-a-main/service-a","--file","/usr/local/service-a-main/config.yaml"]
