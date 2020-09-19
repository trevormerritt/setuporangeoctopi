#!/bin/bash

INSTALL_BASE=/home/pi/
CODE_BASE=`pwd`
VIRTUALENV='/usr/bin/python /usr/lib/python2.7/dist-packages/virtualenv.py'
OUTPUT_FILE='setup.log'
SCRIPT_VERSION=0.1.1
SCRIPT_NAME='SetupOrangeOctoPrint'
SCRIPT_DATE="20200919"
SIGNAL_CLI_VERSION="0.6.10"

declare -A PLUGINS

PLUGINS["ThermalRunaway"]="https://github.com/AlexVerrico/Octoprint-ThermalRunaway/archive/master.zip"
PLUGINS["ConsolidatedTabs"]="https://github.com/jneilliii/OctoPrint-ConsolidatedTabs/archive/master.zip"
PLUGINS["DeltaMicroCalibrator"]="https://github.com/Fabi0San/DuCalibrator/archive/master.zip"
PLUGINS["SimpleFileManager"]="https://github.com/Salandora/OctoPrint-FileManager/archive/master.zip"
PLUGINS["ConsolicatedTempControl"]="https://github.com/jneilliii/OctoPrint-ConsolidateTempControl/archive/master.zip"
PLUGINS["BedVisualizer"]="https://github.com/jneilliii/OctoPrint-BedLevelVisualizer/archive/master.zip"
PLUGINS["AutoSelectUploaded"]="https://github.com/OctoPrint/OctoPrint-Autoselect/archive/master.zip"
PLUGINS["FullScreenWebcam"]="https://github.com/BillyBlaze/OctoPrint-FullScreen/archive/master.zip"
PLUGINS["HeaterTimeout"]="https://github.com/tjjfvi/OctoPrint-BetterHeaterTimeout/archive/master.zip"
PLUGINS["HeaterFailsafe"]="https://github.com/google/OctoPrint-TemperatureFailsafe/archive/master.zip"
PLUGINS["MultipleUpload"]="https://github.com/eyal0/OctoPrint-MultipleUpload/archive/master.zip"
PLUGINS["SignalNotifications"]="https://github.com/aerickson/OctoPrint_Signal-Notifier/archive/master.zip"
PLUGINS["Preheat"]="https://github.com/marian42/octoprint-preheat/archive/master.zip"
PLUGINS["RequestSpinner"]="https://github.com/OctoPrint/OctoPrint-RequestSpinner/archive/master.zip"
PLUGINS["SlackNotifications"]="https://github.com/richjoyce/OctoPrint-Slack/archive/master.zip"
PLUGINS["OctoKlipper"]="https://github.com/AliceGrey/OctoprintKlipperPlugin/archive/master.zip"

function usage() {
  echo "$SCRIPT_NAME v$SCRIPT_VERSION ($SCRIPT_DATE)"
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
  sudo usermod -a -G tty pi
  sudo usermod -a -G dialout pi
  echo "pi ALL=(NOPASSWD: /sbin/shutdown)" > /etc/sudoers.d/octoprint-shutdown
  echo "pi ALL=NOPASSWD: /usr/sbin/service" > /etc/sudoers.d/octoprint-service
}

function apt_steps() {
  echo_green "--Updating Cache"
  sudo apt-get update -y &> $OUTPUT_FILE

  echo_green "Removing Extras"
  sudo apt-get remove -y --purge scratch squeak-plugins-scratch squeak-vm \
   wolfram-engine python-minecraftpi minecraft-pi sonic-pi oracle-java8-jdk \
   bluej libreoffice-common libreoffice-core freepats greenfoot \
   nodered &> $OUTPUT_FILE

  echo_green "--Adding support software for Octoprint"
  sudo apt-get -y --force-yes install python2.7 python-virtualenv python-dev \
    git screen subversion cmake checkinstall avahi-daemon \
    libavahi-compat-libdnssd1 libffi-dev libssl-dev libjpeg62-turbo-dev \
    ssl-cert haproxy cmake pipx python3-venv python3-dev libpython3-dev \
    python3-wheel python-wheel-common &> $OUTPUT_FILE
  sudo apt-get install --reinstall iputils-ping &> $OUTPUT_FILE
  sudo apt-get -y --force-yes --no-install-recommends install imagemagick \
    libav-tools libv4l-dev &> $OUTPUT_FILE

  echo_green "--Updating Software"
  sudo apt-get -y upgrade &> $OUTPUT_FILE
}

function cleanup() {
  echo_green "Cleaning up Space"
  sudo apt-get -y clean &> $OUTPUT_FILE
  echo_green "--Removing no longer needed packages"
  sudo apt-get -y autoremove &> $OUTPUT_FILE
}

function setup_venv() {
  echo_green "Setting up pipx"
  cd $INSTALL_BASE
}

function setup_octoprint() {
  echo_green "Settings up Octoprint"
  cd $INSTALL_BASE
  pipx ensurepath
  pipx install octoprint
  pipx inject octoprint wheel
  echo_green "--Setting up Auto-Start and Defaults"
  sudo cp $CODE_BASE/files/etc_initd_octoprint /etc/init.d/octoprint
  sudo cp $CODE_BASE/files/etc_default_octoprint /etc/default/octoprint
  sudo chmod +x /etc/init.d/octoprint
  sudo update-rc.d octoprint defaults 95
}

function setup_octoprint_plugins() {

for key in ${!PLUGINS[@]}; do
    echo Downloading ${key}
    # curl -L https://github.com/AliceGrey/OctoprintKlipperPlugin/archive/master.zip > OctoprintKlipper.zip
    curl -L ${PLUGINS[${key}]} > ${key}.zip
    echo Installing
    pipx inject octoprint ${key}.zip
done

}

function setup_mjpg_streamer() {
  echo_green "Setting up mjpg_streamer"
  cd $INSTALL_BASE
  git clone https://github.com/jacksonliam/mjpg-streamer.git mjpg-streamer > $OUTPUT_FILE
  sudo chown -R pi:pi mjpg-streamer
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

  sudo cp $CODE_BASE/files/mjpg_www_index /home/pi/mjpg-streamer/www-octopi/index.html
  sudo cp $CODE_BASE/files/etc_initd_webcamd /etc/init.d/webcamd
  sudo cp $CODE_BASE/files/etc_default_webcamd /etc/default/webcamd
  sudo mkdir /root/bin
  sudo cp $CODE_BASE/files/root_bin_webcamd /root/bin/webcamd
  sudo chmod +x /root/bin/webcamd
  sudo chmod +x /etc/init.d/webcamd
  sudo update-rc.d webcamd defaults

}

function setup_signal_support() {
  echo_green "Installing Signal Support"
  cd $CODE_BASE
  mkdir signal-cli
  cd signal-cli
  wget https://github.com/AsamK/signal-cli/releases/download/v"${SIGNAL_CLI_VERSION}"/signal-cli-"${SIGNAL_CLI_VERSION}".tar.gz
  sudo tar xf signal-cli-"${SIGNAL_CLI_VERSION}".tar.gz -C /opt
  sudo ln -sf /opt/signal-cli-"${SIGNAL_CLI_VERSION}"/bin/signal-cli /usr/local/bin/

}

function setup_haproxy() {
  echo_green "Building HAProxy configuration"
  cp $CODE_BASE/files/etc_haproxy_haproxycfg /etc/haproxy/haproxy.cfg
  sudo service haproxy restart
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
#  cleanup
  # shutdown now -r
else
  usage
fi
