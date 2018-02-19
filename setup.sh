#!/bin/bash

INSTALL_BASE=/home/pi/
CODE_BASE=`pwd`

if [[ $UID -ne 0 ]]; then
  sudo -p 'Restarting as root, password: ' bash $0 "$@"
  exit $?
fi

function echo_green(){
  echo -e "\e[92m$1\e[0m"
}

function setup_user_pi() {
  echo_green "Setting up PI user"
  usermod -a -G tty pi
  usermod -a -G dialout pi
  echo "pi ALL=NOPASSWD: /sbin/shutdown" > /etc/sudoers.d/octoprint-shutdown
  echo "pi ALL=NOPASSWD: /usr/sbin/service" > /etc/sudoers.d/octoprint-service
}

function apt_steps() {
  echo_green "Removing Extras"
  apt-get remove -qq -y --purge scratch squeak-plugins-scratch squeak-vm \
   wolfram-engine python-minecraftpi minecraft-pi sonic-pi oracle-java8-jdk \
   bluej libreoffice-common libreoffice-core freepats greenfoot \
   nodered &> /dev/null

  echo_green "--Adding support software for Octoprint"
  apt-get -qq -y --force-yes install python2.7 python-virtualenv python-dev \
    git screen subversion cmake checkinstall avahi-daemon \
    libavahi-compat-libdnssd1 libffi-dev libssl-dev libjpeg62-turbo-dev \
    ssl-cert haproxy &> /dev/null
  apt-get -qq install --reinstall iputils-ping &> /dev/null
  apt-get -qq -y --force-yes --no-install-recommends install imagemagick \
    libav-tools libv4l-dev &> /dev/null

  echo_green "--Updating Cache"
  apt-get update -qq -y &> /dev/null
  echo_green "--Updating Software"
  apt-get -qq -y upgrade &> /dev/null
}

function cleanup() {
  echo_green "Cleaning up Space"
  apt-get -y clean &> /dev/null
  echo_green "--Removing no longer needed packages"
  apt-get -y autoremove &> /dev/null
}

function setup_venv() {
  echo_green "Setting up virtualenv and pip"
  sudo -u pi virtualenv oprint &> /dev/null
  sudo -u pi /home/pi/oprint/bin/pip install --upgrade pip &> /dev/null
}

function setup_octoprint() {
  echo_green "Downloading Octoprint"
  cd $INSTALL_BASE
  git clone https://github.com/foosel/OctoPrint.git OctoPrint &> /dev/null
  cd OctoPrint
  echo_green "--Building Octoprint"
  sudo -u pi /home/pi/oprint/bin/python setup.py install &> /dev/null
  echo_green "--Setting up Octoprint in Environment"
  cd ..
  cp $CODE_BASE/files/etc_initd_octoprint /etc/init.d/octoprint
  cp $CODE_BASE/files/etc_default_octoprint /etc/default/octoprint

  update-rc.d octoprint defaults 95
}

function setup_octoprint_plugins() {
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/OctoPrint/OctoPrint-Autoselect/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/OctoPrint/OctoPrint-DisplayProgress/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/jasiek/OctoPrint-Cost/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/dattas/OctoPrint-DetailedProgress/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/Salandora/OctoPrint-FileManager/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/kantlivelong/OctoPrint-PSUControl/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/malnvenshorn/OctoPrint-CostEstimation/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/google/OctoPrint-HeaterTimeout/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/marian42/octoprint-preheat/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/pablogventura/Octoprint-ETA/archive/master.zip"
  sudo -u pi /home/pi/oprint/bin/pip install "https://github.com/OctoPrint/OctoPrint-FirmwareUpdater/archive/master.zip"
}

function setup_mjpg_streamer() {
  echo_green "Setting up mjpg_streamer"
  cd $INSTALL_BASE
  git clone https://github.com/jacksonliam/mjpg-streamer.git mjpg-streamer > /dev/null
  cd mjpg-streamer
  echo_green "--Building binaries"
  sudo -u pi make > /dev/null
  mkdir www-octopi
  echo_green "--Building webpages"
  rm /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem
  cp $CODE_BASE/files/mjpg_www_index /home/pi/mjpg-streamer/www-octopi/index.html
  cp $CODE_BASE/files/etc_default_webcamd /etc/init.d/webcamd
  update-rc.d webcamd defaults
}

function setup_haproxy() {
  echo_green "Building HAProxy configuration"
  cp $CODE_BASE/files/etc_haproxy_haproxycfg /etc/haproxy/haproxy.cfg
  service haproxy restart
}

clear
echo_green "Starting to install..."
apt_steps
echo_green "...Install of packages complete"
echo_green "Fixing SSH"
echo "IPQoS 0x00" >> /etc/ssh/sshd_config

setup_user_pi
setup_venv
setup_octoprint
setup_octoprint_plugins
setup_mjpg_streamer
setup_haproxy
cleanup
