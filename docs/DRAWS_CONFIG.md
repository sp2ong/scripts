## UDRC / DRAWS Raspberry Pi image


[Set up a Raspberry Pi micro SD Card](DRAWS_CONFIG_SDCARD.md)

* Boot the newly provisioned microSD card

```
login: pi
passwd: digiberry
```

* Immediately verify that the DRAWS hat and its driver are operating.
  * Open a console and type:
```
aplay -l
```
* You should see a line in the output that looks something like this:
```
card 0: udrc [udrc], device 0: bcm2835-i2s-tlv320aic32x4-hifi tlv320aic32x4-hifi-0 []
```

* If you do **NOT** see _udrc_ enumerated  **do NOT continue**
  * Until the UDRC/DRAWS drivers are loaded the configuration scripts will **NOT** succeed.

### Initial Configuration
* Run initcfg.sh script
```
cd
cd n7nix/config
./initcfg.sh
```
* **The above _initcfg.sh_ script completes by rebooting the first time it is run**

* Upon logging in after automatic reboot:
  * Verify DRAWS codec is still enumerated
```
aplay -l
```
* Should see something similar to below:
```
$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: b1 [bcm2835 HDMI 1], device 0: bcm2835 HDMI 1 [bcm2835 HDMI 1]
  Subdevices: 3/4
  Subdevice #0: subdevice #0
  Subdevice #1: subdevice #1
  Subdevice #2: subdevice #2
  Subdevice #3: subdevice #3
card 1: Headphones [bcm2835 Headphones], device 0: bcm2835 Headphones [bcm2835 Headphones]
  Subdevices: 4/4
  Subdevice #0: subdevice #0
  Subdevice #1: subdevice #1
  Subdevice #2: subdevice #2
  Subdevice #3: subdevice #3
card 2: udrc [udrc], device 0: bcm2835-i2s-tlv320aic32x4-hifi tlv320aic32x4-hifi-0 [bcm2835-i2s-tlv320aic32x4-hifi tlv320aic32x4-hifi-0]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
```

### Set your ALSA configuration

* **You must set your ALSA configuration** for your particular radio at this time
  * Also note which connector you are using as you can vary ALSA settings based on which channel you are using
    * On a DRAWS hat left connector is left channel
    * On a UDRC II hat mDin6 connector is right channel
  * You also must route the AFOUT, compensated receive signal or the DISC, discriminator  receive signal with ALSA settings.
  * Verify your ALSA settings by running ```alsa-show.sh```

*  [Link to verify your installation is working properly](https://github.com/nwdigitalradio/n7nix/blob/master/docs/VERIFY_CONFIG.md)

* **NOTE:** running the _init.cfg_ script leaves AX.25 & _direwolf_ **NOT running** & **NOT enabled**
  * The default config is to run HF applications like js8call, wsjtx
  and FLdigi
  * If you are **not** interested in packet and want to run an HF app then go ahead & do that now.

### If you want to run Packet Turn on Direwolf & AX.25

  * If you want to run a **packet application** or run some tests on the
  DRAWS board that requires _direwolf_ then enable AX.25 and Direwolf by running the following command:

```
ax25-start
```

#### Packet Program Options
[Packet Options](DRAWS_CONFIG_PACKET.md)

#### HF Program Options
[HF  Options](DRAWS_CONFIG_HF.md)

### ----- Initial Configuration Completed -----
* The following are miscellaneous notes

#### To Disable the RPi On-Board Audio Device

* The default configuration enables the RPi on board bcm2835 sound device
* If for some reason you want to disable the sound device then:
  * As root comment the following line in _/boot/config.txt_
  * ie. put a hash (#) character at the beginning of the line.
```
dtparam=audio=on
```
* You need to reboot for any changes in _/boot/config.txt_ to take effect
* after a reboot verify by listing all the sound playback hardware devices:
```
aplay -l
```

#### Make your own Raspberry Pi image
* The driver required by the NW Digital Radio is now in the main line Linux kernel (version 4.19.66)
* To make your own Raspberry Pi image
  * Download the lastest version of Raspbian [from here](https://www.raspberrypi.org/downloads/raspbian/)
    * Choose one of:
      * Raspbian Buster Lite
      * Raspbian Buster with desktop
      * desktop and recommended software
* Add the following lines to the bottom of /boot/config.txt
```
dtoverlay=
dtoverlay=draws,alsaname=udrc
force_turbo=1
```
* If you want to ssh into your device then add an ssh file to the _/boot_ directory
```
touch /boot/ssh
```

* Boot the new micro SD card.

### Placing A Hold On Kernel Upgrade - *for reference ONLY*

* You do **NOT** need to put a hold on kernel upgrades as of Oct/2021 with kernel 5.10.52 or newer
  * There was a problem found in Feb/2021 with kernels newer than 5.4.83 but that problem has been fixed since kernel versiion 5.10.52.


  * To verify your current kernel version
```
uname -a
```
* If you see : ```5.10.11-v7l``` then your DRAWS system will have problems
  * The problem occurs in clk_hw_create_clk
    * refcount_t: addition on 0; use-after-free
    * tlv320aic32x4 1-0018: Failed to get clk 'bdiv': -2
  * To revert your kernel back to 5.4.79-v7l+ run the following:
```
sudo rpi-update 0642816ed05d31fb37fc8fbbba9e1774b475113f
```

* Do **NOT** use the following commands:
  * _apt-get dist-upgrade_
  * _apt full-upgrade_

#### Verify a hold is placed on kernel upgrades
* In a console run the following command:
```
apt-mark showhold
```
* should see this in console output
```
libraspberrypi-bin
libraspberrypi-dev
libraspberrypi-doc
libraspberrypi0
raspberrypi-bootloader
raspberrypi-kernel
raspberrypi-kernel-headers
```
* If you did not see the above console output then place a hold on kernel upgrades by executing the following 2 hold commands as root:
```
sudo su
apt-mark hold libraspberrypi-bin libraspberrypi-dev libraspberrypi-doc libraspberrypi0
apt-mark hold raspberrypi-bootloader raspberrypi-kernel raspberrypi-kernel-headers
```
* Once you confirm that there is a hold on the Raspberry Pi kernel it is safe to upgrade other programs. ie. you can do the following:
```
sudo apt-get dist-upgrade
sudo apt full-upgrade
```
### To unhold ALL held packages
* Use the following command:
```
apt-mark unhold $(apt-mark showhold)
```

#### Historical Kernel Hold Info
##### Spring 2020 Kernel Hold
* Revert kernel 5.4.51 # back to 4.19.118-v7l+
* You should see: ```4.19.118-v7l+```
* If you see : ```5.4.51-v7l+``` then your DRAWS hat will have problems
  * The driver for the TI ads1015 chip is missing in this kernel.
  * To revert your kernel back to 4.19.118 run the following (courtesy of Thomas KF7RSF):
```
sudo rpi-upgrade e1050e94821a70b2e4c72b318d6c6c968552e9a2
```
##### Spring 2021 Kernel Hold
* Revert kernel 5.10.11-v7l+ #1399 SMP Thu Jan 28 12:09:48 GMT 2021
  * to kernel 5.4.79-v7l+ #1373 SMP Mon Nov 23 13:27:40

```
sudo rpi-update 0642816ed05d31fb37fc8fbbba9e1774b475113f
```

##### Fall of 2021 Kernel Hold is **NOT** required
* Kernels 5.10.52 and newer work fine with the DRAWS codec drivers
