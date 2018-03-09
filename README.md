** USAGE **

- Install Armbian.
- On first boot, change root password, then add a user named 'pi'
- After the user is created, connect to the internet and clone the repo 'somewhere'.  I use /home/pi resulting in /home/pi/setuporangeoctopi
- Run /home/pi/setuporangeoctopi/setup.sh --install.sh
-This takes ~45 mins.  Wait.

- After reboot, you have:
  - Octoprint
  - ffmpeg-streamer
  - haproxy
  - Octoprint-Plugins (Stuff I picked)

** TODO **
- MOTD message before login (show IP as machine security is lower priority to access)
- Spinner during steps on silent install
- Check for 'pi' user and create it if it doesn't exist
- Make 'pi' username configurable
- Colours for output on success/failure of steps
- Better interface to show step in the process
