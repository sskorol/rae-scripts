## RAE Scripts

This repo contains a set of useful scripts that help to address different RAE issues.

### Prerequisites

As RAE build doesn't have git pre-installed and there's no package manager available,
you have to clone sources to your host, and then copy them to RAE:
```shell
git clone https://github.com/sskorol/rae-scripts.git && \
    zip -r rae-scripts.zip rae-scripts && \
    scp rae-scripts.zip root@192.168.197.55:~/ && \
    ssh root@192.168.197.55 && \
    unzip rae-scripts.zip
```

### Setting up persistent Wi-Fi

```shell
ssh root@192.168.197.55 # must be connected via usb cable
# Disable RobotHub services
systemctl disable robothub-tunnel
systemctl disable robothub-agent

cd ~/rae-scripts
mkdir ~/boot && cp ./wifi/start_wifi.sh ~/boot
cp ./wifi/wifi-setup.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable wifi-setup.service
```

### Installing the latest RAE build

```shell
cd ~/rae-scripts/os
python3 -m venv .venv
source .venv/bin/activate
pip3 install pip --upgrade
pip3 install -r requirements.txt
python3 install_build.py
```

### Checking the RAE temperature

```shell
cd ~/rae-scripts/status
./temp.sh
```

### Running RAE ROS container

```shell
cd ~/rae-scripts/docker
./start.sh
# Running basic control stack
ros2 launch rae_bringup robot.launch.py
# Running full stack
ros2 launch rae_bringup bringup.launch.py
```

Note that the full stack currently have issues. Disabling [mic and speakers nodes](https://github.com/luxonis/rae-ros/blob/humble/rae_hw/launch/peripherals.launch.py#L43-L52) did the trick for me. It should be fixed in the upcoming releases.
