# Creates docker container that runs HCP Pipeline algorithms
# Maintainer: Amy Hegarty (amy.hegarty@colorado.edu)
#

FROM ubuntu:focal as base
#
LABEL maintainer="Amy Hegarty <amy.hegarty@colorado.edu>"

# ------------- INSTALLING R ------------- #
## Set a default user. Available via runtime flag `--user docker`
## Add user to 'staff' group, granting them write privileges to /usr/local/lib/R/site.library
## User should also have & own a home directory (for rstudio or linked volumes to work properly).
RUN useradd flywheel \
	&& mkdir /home/flywheel \
	&& chown flywheel:flywheel /home/flywheel \
	&& addgroup flywheel users

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

## Configure default locale, see https://github.com/rocker-org/rocker/issues/19
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

## This was not needed before but we need it now
ENV DEBIAN_FRONTEND noninteractive

## Otherwise timedatectl will get called which leads to 'no systemd' inside Docker
ENV TZ UTC

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		software-properties-common \
                dirmngr \
                ed \
		less \
		locales \
		vim-tiny \
		wget \
        ca-certificates \
        git \
    && add-apt-repository --enable-source --yes "ppa:marutter/rrutter4.0" \
    && add-apt-repository --enable-source --yes "ppa:c2d4u.team/c2d4u4.0+"

# Now install R and littler, and create a link for littler in /usr/local/bin
# Default CRAN repo is now set by R itself, and littler knows about it too
# r-cran-docopt is not currently in c2d4u so we install from source
RUN apt-get update \
        && apt-get install -y --no-install-recommends \
                 littler \
 		 r-base \
 		 r-base-dev \
 		 r-recommended \
         tcsh \
         csh \
         r-cran-docopt \
  	&& ln -s /usr/lib/R/site-library/littler/examples/install.r /usr/local/bin/install.r \
 	&& ln -s /usr/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
 	&& ln -s /usr/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
 	&& ln -s /usr/lib/R/site-library/littler/examples/testInstalled.r /usr/local/bin/testInstalled.r \
 	&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds \
 	&& rm -rf /var/lib/apt/lists/*


# ------------- INSTALLING PYTHON ------------- #
#install python
RUN	apt update -qq \
    && apt-get install -y --no-install-recommends python3.9 \
      python3.9-dev \
	  python3.9-venv \
	  python3-pip  \
      python-is-python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/abin/:$PATH"
#
#RUN cd /usr/ \
#    && curl -O https://raw.githubusercontent.com/afni/afni/master/src/other_builds/OS_notes.linux_ubuntu_22_64_a_admin.txt \
#    && curl -O https://raw.githubusercontent.com/afni/afni/master/src/other_builds/OS_notes.linux_ubuntu_22_64_b_user.tcsh \
#    && curl -O https://raw.githubusercontent.com/afni/afni/master/src/other_builds/OS_notes.linux_ubuntu_22_64_c_nice.tcsh \
#    && tcsh OS_notes.linux_ubuntu_22_64_b_user.tcsh 2>&1 | tee o.ubuntu_22_b.txt
#
## fixes
#RUN cp /root/abin//AFNI.afnirc ~/.afnirc \
#    && suma -update_env \


#
RUN apt-get install -y -q --no-install-recommends software-properties-common  \
    && apt-get update -qq \
    && add-apt-repository universe \
    && add-apt-repository ppa:ubuntu-toolchain-r/test \
    && add-apt-repository -y "ppa:marutter/rrutter4.0" \
    && add-apt-repository -y "ppa:c2d4u.team/c2d4u4.0+"


# ------------- INSTALLING AFNI ------------- #
RUN apt update -qq \
    && apt-get install -y -q --no-install-recommends \
        tcsh xfonts-base libssl-dev       \
        python-is-python3                 \
        python3-matplotlib python3-numpy  \
        python3-pil                       \
        gsl-bin netpbm gnome-tweaks       \
        libjpeg62 xvfb xterm vim curl     \
        gedit evince eog                  \
        libglu1-mesa-dev libglw1-mesa     \
        libxm4 build-essential            \
        libcurl4-openssl-dev libxml2-dev  \
        libgfortran-11-dev libgomp1       \
        gnome-terminal nautilus           \
        firefox xfonts-100dpi             \
        r-base-dev cmake                  \
        libgdal-dev libopenblas-dev       \
        libnode-dev libudunits2-dev

RUN ln -s /usr/lib/x86_64-linux-gnu/libgsl.so.23 /usr/lib/x86_64-linux-gnu/libgsl.so.19

RUN cd  /usr/ \
    && curl -O https://afni.nimh.nih.gov/pub/dist/bin/misc/@update.afni.binaries \
    && tcsh @update.afni.binaries -package linux_ubuntu_16_64 -do_extras


RUN export R_LIBS=/usr/R         \
   && mkdir  $R_LIBS              \
   && echo  'setenv R_LIBS ~/R'     >> ~/.cshrc         \
   && echo  'export R_LIBS=$HOME/R' >> ~/.bashrc        \
   && curl -O https://afni.nimh.nih.gov/pub/dist/src/scripts_src/@add_rcran_ubuntu.tcsh

#RUN tcsh @add_rcran_ubuntu.tcsh

RUN rPkgsInstall -pkgs ALL

RUN afni_system_check.py -check_all

RUN cp /root/abin//AFNI.afnirc ~/.afnirc  \
    && suma -update_env

#
# install zip and unzip
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           zip \
           unzip \
           rsync \
    && apt-get clean

######################################################
# FLYWHEEL GEAR STUFF...

# Add poetry oversight.
RUN apt-get update &&\
    apt-get install -y --no-install-recommends \
	 git \
     zip \
    software-properties-common &&\
	add-apt-repository -y 'ppa:deadsnakes/ppa' &&\
	apt-get update && \
	apt-get install -y --no-install-recommends python3.9\
    python3.9-dev \
	python3.9-venv \
	python3-pip &&\
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


RUN apt-get update && apt-get install -y git zip unzip && \
    pip install "poetry==1.1.13"

COPY pyproject.toml poetry.lock ./
RUN poetry install --no-dev --no-root

COPY run.py manifest.json $FLYWHEEL/
COPY fw_gear_afni_curator $FLYWHEEL/fw_gear_afni_curator
COPY curator $FLYWHEEL/curator
RUN poetry install --no-dev

# Configure entrypoint
RUN chmod a+x $FLYWHEEL/run.py
ENTRYPOINT ["poetry","run","python","/flywheel/v0/run.py"]
