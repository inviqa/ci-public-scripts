#!/bin/bash
if [ ! -f ~/build/vendor/firefox_28.0+build2-0ubuntu2_amd64.deb ]; then
  wget "http://security.ubuntu.com/ubuntu/pool/main/f/firefox/firefox_28.0+build2-0ubuntu2_amd64.deb" -O ~/build/vendor/firefox_28.0+build2-0ubuntu2_amd64.deb
fi
sudo dpkg -i ~/build/vendor/firefox_28.0+build2-0ubuntu2_amd64.deb
