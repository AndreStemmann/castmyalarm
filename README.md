# castmyalarm
Wrapper-Script for stream2chromcast.py

- Since Google Home App lacks the ability to set an Alarm for 
Google Chromecast Audio Devices, here's my approach for a simple workaround
- Deploy stream2chromecast
- Deploy this script in the /stream2chromecast directory and adapt the variables as needed
  - you may want to get a list of your configured devices first
  - python stream2chromecast -devicelist
- Set a crontab for your alarm
  - 30  7   *   *   1-5 /bin/bash /opt/stream2chromecast/castmyalarm.sh
- wakeup with your fav' radiostream
