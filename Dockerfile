# FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04
ARG  CUDAGL_VERSION=11.0-devel-ubuntu20.04
FROM  nvidia/cudagl:$CUDAGL_VERSION

# Comment the line above and uncomment the line below for Ubuntu 18.04
#FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04

LABEL maintainer "https://github.com/ehfd"

# Make all NVIDIA GPUs visible
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES all

# Default options (password is "mypasswd")
ENV TZ UTC
ENV PASSWD mypasswd
ENV SIZEW 1920
ENV SIZEH 1080
ENV CDEPTH 24

# Install locales to prevent errors
RUN apt-get clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install MATE desktop and others
RUN apt-get update && apt-get install -y \
        software-properties-common \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        wget \
        gzip \
        zip \
        unzip \
        gcc \
        git \
        make \
        python \
        python-numpy \
        python3 \
        python3-numpy \
        openssh-server \
        openssh-sftp-server \
        mlocate \
        nano \
        vim \
        htop \
        firefox \
        supervisor \
        net-tools \
        ubuntu-mate-desktop && \
    # Remove Bluetooth packages that throw errors
    apt-get autoremove --purge -y blueman bluez bluez-cups pulseaudio-module-bluetooth && \
    rm -rf /var/lib/apt/lists/*

# Install Vulkan (for offscreen rendering only)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 \
        vulkan-utils && \
    rm -rf /var/lib/apt/lists/* && \
    VULKAN_API_VERSION=`dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)'` && \
    mkdir -p /etc/vulkan/icd.d/ && \
    echo "{\n\
    \"file_format_version\" : \"1.0.0\",\n\
    \"ICD\": {\n\
        \"library_path\": \"libGLX_nvidia.so.0\",\n\
        \"api_version\" : \"${VULKAN_API_VERSION}\"\n\
    }\n\
}" > /etc/vulkan/icd.d/nvidia_icd.json


## Install nomachine
RUN curl -fSL "https://www.nomachine.com/free/linux/64/deb" -o nomachine.deb &&\
    dpkg -i nomachine.deb &&\
    rm nomachine.deb &&\
    sed -i "s|#EnableClipboard both|EnableClipboard both |g" /usr/NX/etc/server.cfg &&\
    sed -i '/DefaultDesktopCommand/c\DefaultDesktopCommand "/usr/bin/mate-session"' /usr/NX/etc/node.cfg


# Wine and Winetricks, comment out the below lines to disable
# ARG WINE_BRANCH=stable
# RUN if [ "$(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2)" = "bionic" ]; then add-apt-repository ppa:cybermax-dexter/sdl2-backport; fi && \
#     curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - && \
#     apt-add-repository "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" && \
#     apt-get update && apt-get install -y --install-recommends winehq-${WINE_BRANCH} && \
#     rm -rf /var/lib/apt/lists/* && \
#     curl -fsSL -o /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
#     chmod 755 /usr/bin/winetricks && \
#     curl -fsSL -o /usr/share/bash-completion/completions/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion

# VirtualGL and TurboVNC
ARG VIRTUALGL_VERSION=2.6.90
ARG TURBOVNC_VERSION=2.2.6
RUN curl -fsSL -O https://sourceforge.net/projects/virtualgl/files/virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    curl -fsSL -O https://sourceforge.net/projects/virtualgl/files/virtualgl32_${VIRTUALGL_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./virtualgl_${VIRTUALGL_VERSION}_amd64.deb ./virtualgl32_${VIRTUALGL_VERSION}_amd64.deb && \
    rm virtualgl_${VIRTUALGL_VERSION}_amd64.deb virtualgl32_${VIRTUALGL_VERSION}_amd64.deb && \
    chmod u+s /usr/lib/libvglfaker.so && \
    chmod u+s /usr/lib/libdlfaker.so && \
    chmod u+s /usr/lib32/libvglfaker.so && \
    chmod u+s /usr/lib32/libdlfaker.so && \
    chmod u+s /usr/lib/i386-linux-gnu/libvglfaker.so && \
    chmod u+s /usr/lib/i386-linux-gnu/libdlfaker.so && \
    curl -fsSL -O https://sourceforge.net/projects/turbovnc/files/turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm -rf /var/lib/apt/lists/* && \
    echo -e "no-remote-connections\n\
no-httpd\n\
no-x11-tcp-connections\n\
no-pam-sessions\n\
permitted-security-types = VNC, otp\
" > /etc/turbovncserver-security.conf

# ssh 
RUN mkdir /var/run/sshd &&  \
    sed -i 's/#*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

# # Apache Guacamole
# ENV TOMCAT_VERSION 9.0.50
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     libcairo2-dev \
#     libjpeg-turbo8-dev \
#     libpng-dev \
#     libtool-bin \
#     libossp-uuid-dev \
#     libavcodec-dev \
#     libavformat-dev \
#     libavutil-dev \
#     libswscale-dev \
#     freerdp2-dev \
#     libpango1.0-dev \
#     libssh2-1-dev \
#     libtelnet-dev \
#     libvncserver-dev \
#     libwebsockets-dev \
#     libpulse-dev \
#     libssl-dev \
#     libvorbis-dev \
#     libwebp-dev \
#     autoconf \
#     automake \
#     autotools-dev \
#     pulseaudio \
#     pavucontrol \
#     openssh-server \
#     openssh-sftp-server \
#     default-jdk \
#     maven && \
#     rm -rf /var/lib/apt/lists/* && \
#     curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-$(echo $TOMCAT_VERSION | cut -d "." -f 1)/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar -xzf - -C /opt && \
#     mv /opt/apache-tomcat-$TOMCAT_VERSION /opt/tomcat && \
#     git clone https://github.com/apache/guacamole-server.git /tmp/guacamole-server && \
#     cd /tmp/guacamole-server && autoreconf -fi && ./configure --with-init-dir=/etc/init.d && make install && ldconfig && cd / && rm -rf /tmp/* && \
#     git clone https://github.com/apache/guacamole-client.git /tmp/guacamole-client && \
#     cd /tmp/guacamole-client && JAVA_HOME=/usr/lib/jvm/default-java mvn package && rm -rf /opt/tomcat/webapps/* && mv guacamole/target/guacamole*.war /opt/tomcat/webapps/ROOT.war && chmod +x /opt/tomcat/webapps/ROOT.war && cd / && rm -rf /tmp/* && \
#     echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.0/8 auth-anonymous=1" >> /etc/pulse/default.pa

# Create user with password ${PASSWD}
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1008 user && \
    useradd -ms /bin/bash user -u 1008 -g 1008 && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,input,lp,lpadmin,netdev,plugdev,scanner,ssh,sudo,tape,tty,video,voice user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    # chown -R user:user /home/user /opt/tomcat && \
    chown -R user:user /home/user && \
    echo "user:${PASSWD}" | chpasswd && \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone

COPY entrypoint.sh /etc/entrypoint.sh
RUN chmod 755 /etc/entrypoint.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

EXPOSE 22
EXPOSE 8080
EXPOSE 4000

USER user
WORKDIR /home/user

ENTRYPOINT ["/usr/bin/supervisord"]
