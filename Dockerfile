FROM centos:centos7.9.2009

RUN yum update -y

RUN yum -y erase vim-minimal iputils libss && \
    yum -y install openssh openssh-server openssh-clients && \
    yum -y clean all

RUN mkdir /var/run/sshd
RUN echo 'root:toor' | chpasswd
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# ENV NOTVISIBLE "in users profile"
# RUN echo "export VISIBLE=now" >> /etc/profile

RUN test -f /etc/ssh/ssh_host_ecdsa_key || /usr/bin/ssh-keygen -q -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -C '' -N ''
RUN test -f /etc/ssh/ssh_host_rsa_key || /usr/bin/ssh-keygen -q -t rsa -f /etc/ssh/ssh_host_rsa_key -C '' -N ''
RUN test -f /etc/ssh/ssh_host_ed25519_key || /usr/bin/ssh-keygen -q -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -C '' -N ''
RUN test -f /root/.ssh/id_rsa || /usr/bin/ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
RUN test -f /root/.ssh/id_rsa.pub || ssh-keygen -y -t rsa -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
RUN test -f /root/.ssh/authorized_keys || /usr/bin/cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

RUN yum install -y yum-utils 
RUN yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 
RUN yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

RUN yum -y install epel-release wget make
RUN yum -y install apt-transport-https ca-certificates software-properties-common gcc
RUN yum -y install git curl rsync podman
RUN yum install openssl11 openssl11-devel -y

RUN mkdir /usr/local/openssl

RUN cd /usr/local/openssl && wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz && tar xvf openssl-1.1.1w.tar.gz && cd openssl-1.1*/ && ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl && make && make install && ldconfig

RUN yum groupinstall "Development Tools" -y

RUN yum -y install gcc openssl-devel bzip2-devel libffi-devel make
RUN curl -O https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tgz
RUN tar -xvf Python-3.10.0.tgz
RUN cd Python-3.10.0 && ./configure --enable-optimizations --prefix=/usr/local --with-ensurepip=install --with-lto --with-computed-gotos --with-system-ffi --enable-shared --with-openssl=/usr/local/openssl --with-ssl && make altinstall
RUN rm Python-3.10.0.tgz

RUN ln -s /usr/local/bin/python3.10 /usr/bin/python3
RUN ln -s /usr/local/bin/pip3.10 /usr/bin/pip3
RUN ln -s /usr/local/bin/idle3.10 /usr/bin/idle
RUN ln -s /usr/local/bin/python3.10-config /usr/bin/python-config

RUN ln -s /usr/local/bin/python3.10 /usr/bin/python3.10
RUN ln -s /usr/local/bin/pip3.10 /usr/bin/pip3.10
RUN ln -s /usr/local/bin/idle3.10 /usr/bin/idle3.10
RUN ln -s /usr/local/bin/python3.10-config /usr/bin/python-config3.10

RUN export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/local/openssl/bin:/usr/local/openssl/lib
RUN export PATH=$PATH:/usr/local/openssl

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/local/openssl/bin:/usr/local/openssl/lib
ENV PATH=$PATH:/usr/local/openssl

RUN pip3 install ansible
RUN pip3 install molecule
RUN pip3 install molecule-docker molecule[docker]
RUN pip3 install ansible-lint yamllint molecule[lint]
ENV MOLECULE_PODMAN_EXECUTABLE=podman-remote
RUN pip3 install molecule-podman molecule[podman]


RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN export LC_CTYPE="en_US.UTF-8"
ENV LC_CTYPE="en_US.UTF-8"

RUN echo -e '\
LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib\n\
export LD_LIBRARY_PATH\n\
export PATH=$PATH:/usr/local/openssl\
' > /root/.bash_profile

RUN ansible-galaxy collection install community.docker  --force
RUN ansible-galaxy collection install ansible.posix --force
RUN ansible-galaxy collection install containers.podman --force

RUN /usr/local/bin/python3.10 -m pip install --upgrade pip

RUN yum -y install podman fuse-overlayfs --exclude container-selinux

RUN yum -y reinstall shadow-utils; \
yum -y install podman fuse-overlayfs --exclude container-selinux; \
rm -rf /var/cache /var/log/dnf* /var/log/yum.*

RUN useradd podman; \
echo podman:10000:5000 > /etc/subuid; \
echo podman:10000:5000 > /etc/subgid;

VOLUME /var/lib/containers
VOLUME /home/podman/.local/share/containers

ADD https://github.com/containers/common/blob/main/pkg/config/containers.conf /etc/containers/containers.conf
# ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf /home/podman/.config/containers/containers.conf

RUN chown podman:podman -R /home/podman

# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /etc/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""


EXPOSE 22

COPY entrypoint.sh /usr/bin/
RUN chmod a+x /usr/bin/entrypoint.sh

ENTRYPOINT ["/bin/bash", "/usr/bin/entrypoint.sh"]
# CMD ["/usr/sbin/sshd", "-D"]