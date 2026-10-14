#!/bin/sh
# Breathing notification LED for 60 s after boot, then off.
L=/sys/class/leds/charging
echo none > $L/trigger
echo 255 > $L/brightness
echo 1 > $L/breath
sleep 60
echo 0 > $L/breath
echo 0 > $L/brightness
