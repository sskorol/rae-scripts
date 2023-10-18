#!/bin/bash

docker run -it -v /dev/:/dev/ -v /sys/:/sys/ --privileged --net=host luxonis/rae-ros-robot:humble /bin/bash
