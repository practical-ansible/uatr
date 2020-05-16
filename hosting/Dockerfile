FROM ubuntu:20.04

# Setup ssh
RUN apt-get update
RUN apt-get install -y openssh-server sudo
RUN echo 'root:test' | chpasswd
RUN mkdir /var/run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Configure non-root user
RUN useradd -m ansible
RUN echo 'ansible:test' | chpasswd
RUN echo "ansible ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

EXPOSE 22/tcp 80/tcp 443/tcp
CMD ["/usr/sbin/sshd", "-D"]
