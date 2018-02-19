#!/bin/bash

INSTALL_BASE=/home/pi/
CODE_BASE=`pwd`
VIRTUALENV='/usr/bin/python /usr/lib/python2.7/dist-packages/virtualenv.py'
OUTPUT_FILE='setup.log'
SCRIPT_VERSION=0.0.1
SCRIPT_NAME='SetupOrangeOctoPrint'

if [[ $UID -ne 0 ]]; then
  sudo -p 'Restarting as root, password: ' bash $0 "$@"
  exit $?
fi

function usage() {
  echo "$SCRIPT_NAME v$SCRIPT_VERSION"
  echo "$0"
  echo " --help (This)"
  echo " --restart-everything (Nuke Everything)"
  echo " --debugging (Turn on more debugging stuff)"
  echo " --install (Install the code)"
  exit 0
}

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
  echo_green "--Updating Cache"
  apt-get update -y &> $OUTPUT_FILE

  echo_green "Removing Extras"
  apt-get remove -y --purge scratch squeak-plugins-scratch squeak-vm \
   wolfram-engine python-minecraftpi minecraft-pi sonic-pi oracle-java8-jdk \
   bluej libreoffice-common libreoffice-core freepats greenfoot \
   nodered &> $OUTPUT_FILE

  echo_green "--Adding support software for Octoprint"
  apt-get -y --force-yes install python2.7 python-virtualenv python-dev \
    git screen subversion cmake checkinstall avahi-daemon \
    libavahi-compat-libdnssd1 libffi-dev libssl-dev libjpeg62-turbo-dev \
    ssl-cert haproxy &> $OUTPUT_FILE
  apt-get install --reinstall iputils-ping &> $OUTPUT_FILE
  apt-get -y --force-yes --no-install-recommends install imagemagick \
    libav-tools libv4l-dev &> $OUTPUT_FILE

  echo_green "--Updating Software"
  apt-get -y upgrade &> $OUTPUT_FILE
}

function cleanup() {
  echo_green "Cleaning up Space"
  apt-get -y clean &> $OUTPUT_FILE
  echo_green "--Removing no longer needed packages"
  apt-get -y autoremove &> $OUTPUT_FILE
}

function setup_venv() {
  echo_green "Setting up virtualenv and pip"
  cd $INSTALL_BASE
  sudo -u pi $VIRTUALENV oprint &> $OUTPUT_FILE
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install --upgrade pip &> $OUTPUT_FILE
}

function setup_octoprint() {
  echo_green "Downloading Octoprint"
  cd $INSTALL_BASE
  git clone https://github.com/foosel/OctoPrint.git OctoPrint &> $OUTPUT_FILE
  chown -R pi:pi OctoPrint
  cd OctoPrint
  echo_green "--Building Octoprint"
  sudo -u pi $INSTALL_BASE/oprint/bin/python setup.py install &> $OUTPUT_FILE
  echo_green "--Setting up Octoprint in Environment"
  cd ..
  cp $CODE_BASE/files/etc_initd_octoprint /etc/init.d/octoprint
  cp $CODE_BASE/files/etc_default_octoprint /etc/default/octoprint
  chmod +x /etc/init.d/octoprint
  update-rc.d octoprint defaults 95
}

function setup_octoprint_plugins() {
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/OctoPrint/OctoPrint-Autoselect/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/OctoPrint/OctoPrint-DisplayProgress/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/jasiek/OctoPrint-Cost/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/dattas/OctoPrint-DetailedProgress/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/Salandora/OctoPrint-FileManager/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/kantlivelong/OctoPrint-PSUControl/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/malnvenshorn/OctoPrint-CostEstimation/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/google/OctoPrint-HeaterTimeout/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/marian42/octoprint-preheat/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/pablogventura/Octoprint-ETA/archive/master.zip"
  sudo -u pi $INSTALL_BASE/oprint/bin/pip install "https://github.com/OctoPrint/OctoPrint-FirmwareUpdater/archive/master.zip"
}

function setup_mjpg_streamer() {
  echo_green "Setting up mjpg_streamer"
  cd $INSTALL_BASE
  git clone https://github.com/jacksonliam/mjpg-streamer.git mjpg-streamer > $OUTPUT_FILE
  chown -R pi:pi mjpg-streamer
  cd mjpg-streamer
  mv mjpg-streamer-experimental/* .
  echo_green "--Building binaries"
  sudo -u pi make > $OUTPUT_FILE
  mkdir www-octopi
  echo_green "--Building webpages"
  if [ -e "/etc/ssl/private/ssl-cert-snakeoil.key" ]
  then
    rm /etc/ssl/private/ssl-cert-snakeoil.key
  fi
  if [ -e "/etc/ssl/certs/ssl-cert-snakeoil.pem" ]
  then
    rm /etc/ssl/certs/ssl-cert-snakeoil.pem
  fi

  cp $CODE_BASE/files/mjpg_www_index /home/pi/mjpg-streamer/www-octopi/index.html
  cp $CODE_BASE/files/etc_initd_webcamd /etc/init.d/webcamd
  cp $CODE_BASE/files/etc_default_webcamd /etc/default/webcamd
  mkdir /root/bin
  cp $CODE_BASE/files/root_bin_webcamd /root/bin/webcamd
  chmod +x /root/bin/webcamd
  chmod +x /etc/init.d/webcamd
  update-rc.d webcamd defaults

}

function setup_haproxy() {
  echo_green "Building HAProxy configuration"
  cp $CODE_BASE/files/etc_haproxy_haproxycfg /etc/haproxy/haproxy.cfg
  service haproxy restart
}

while test $# -gt 0
do
    case "$1" in
        --debugging) DEBUGGING=true
            ;;
        --restart-everything) NUKE_THE_WORLD="true"
            ;;
        --help) usage
            ;;
        --install) DO_INSTALL="true"
            ;;
    esac
    shift
done

if [ -n "$NUKE_THE_WORLD" ]
then
  echo "Nuking folders in $INSTALL_BASE..."
  echo "...oprint"
  sudo rm -rf $INSTALL_BASE/oprint
  echo "...mjpg-streamer"
  sudo rm -rf $INSTALL_BASE/mjpg-streamer
  echo "...octoprint"
  sudo rm -rf $INSTALL_BASE/OctoPrint
  exit 0
fi

if [ -n "$DEBUGGING" ]
then
  set -x
  OUTPUT_FILE=/dev/null
fi

if [ -n "$DO_INSTALL" ]
then

  clear
  echo_green "Starting to install from $CODE_BASE to $INSTALL_BASE..."
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
  shutdown now -r
else
  usage
fi
