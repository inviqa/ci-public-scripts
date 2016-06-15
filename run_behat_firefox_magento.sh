#!/bin/bash

myDIR="$(readlink -f "$(dirname "$0")")"

mkdir -p ~/artifacts
seleniumLog="$HOME/artifacts/selenium.log"
firefoxLog="$HOME/artifacts/firefox.log"

SELENIUM_MAJOR="2.45"
SELENIUM_MINOR="0"
SELENIUM_VERSION="${SELENIUM_MAJOR}.$SELENIUM_MINOR"

SELENIUM_FILE="$myDIR/../bin/selenium-server-standalone-${SELENIUM_VERSION}.jar"
test -f ./bin/selenium-server-standalone-$SELENIUM_VERSION.jar || wget "http://selenium-release.storage.googleapis.com/$SELENIUM_MAJOR/selenium-server-standalone-${SELENIUM_VERSION}.jar" -O ./bin/selenium-server-standalone-${SELENIUM_VERSION}.jar

function fixHostsFileForSelenium() {
    head -n1 /etc/hosts | grep -e '^127.0.0.1\s*localhost' >/dev/null || (
        sudo cp /etc/hosts /etc/hosts.bak
        echo "updating hosts.."
        echo "127.0.0.1   localhost # required as fqdn for selenium not to fail" | sudo tee /etc/hosts
        cat /etc/hosts.bak | sudo tee -a /etc/hosts
    )
}

function prepSeleniumLauncher() {
  echo '#!/bin/sh' > ~/runSelenium.sh
  echo "cd '$myDIR'" >> ~/runSelenium.sh
  echo "export NSPR_LOG_MODULES=all:3" >> ~/runSelenium.sh
  echo "java -jar '$SELENIUM_FILE' -Dwebdriver.firefox.logfile='$firefoxLog' >'$seleniumLog' 2>&1 &" >> ~/runSelenium.sh
  echo 'echo -n "$!" > /tmp/selenium.pid' >> ~/runSelenium.sh
  echo 'wait' >> ~/runSelenium.sh
  chmod +x ~/runSelenium.sh
}

function runSelenium() {
  if test -z "$DISPLAY" ; then
      xvfb-run ~/runSelenium.sh 2>/dev/null &
  else
      ~/runSelenium.sh &
  fi

  sleep 5
  seleniumPID=$(cat '/tmp/selenium.pid')
  echo "seleniumPID: $seleniumPID"

  while ps -p "$seleniumPID" > /dev/null && ! ( cat "$seleniumLog" | grep 'INFO - Started org.openqa.jetty.jetty.Server' > /dev/null ) ; do
      echo "waiting for selenium to start"
      sleep 1
  done

  ps -p "$seleniumPID" >/dev/null || exit 1
}

function runBehat() {
  echo "===== running behat ====="
  pushd "$myDIR/.."
  php -d 'xdebug.max_nesting_level=1000' bin/behat "$@"
  local RETSTATUS="$?"
  popd
  return "$RETSTATUS"
}

function cleanMagentoLogs() {
    rm -f "$firefoxLog"
    rm -f "$seleniumLog"
    rm -f "$myDIR/../public/var/log/exception.log"
    rm -f "$myDIR/../public/var/log/system.log"
}
function copyMagentoLogsToArtifacts() {
    mkdir -p "$HOME/artifacts/magento"
    rm -f "$HOME/artifacts/magento/exception.log"
    rm -f "$HOME/artifacts/magento/system.log"
    test -f "$myDIR/../public/var/log/exception.log" && cp "$myDIR/../public/var/log/exception.log" "$HOME/artifacts/magento/"
    test -f "$myDIR/../public/var/log/system.log" && cp "$myDIR/../public/var/log/system.log" "$HOME/artifacts/magento/"
}

function grepJsErrors() {
    cat "$firefoxLog" | grep -v 'st.magentoiframechild.js\|html5player.js\|html5player-new.js\|gc is not defined' | grep 'JavaScript error:'
    return $?
}

fixHostsFileForSelenium
prepSeleniumLauncher
cleanMagentoLogs
runSelenium
runBehat "$@"
RETSTATUS="$?"
copyMagentoLogsToArtifacts

kill "$seleniumPID"
sleep 3 && ( ps -p "$seleniumPID" >/dev/null && kill -9 "$seleniumPID" )

if test -f "$firefoxLog" ; then
#    if cat "$firefoxLog" | grep 'HTTP/1.1 404 Not Found' >/dev/null ; then
#        cat <<'EOF'
#    there are resources requested that returned 404. this is a
#    particular problem in magento as it actually loads the whole
#    magento framework for every non-existant file requested.
#
#    failed the build
#EOF
#        exit 1
#    fi
    if grepJsErrors >/dev/null ; then
        echo 'There are javascript errors on the tests(failing the build):'
        grepJsErrors
        exit 1
    fi
fi

exit "$RETSTATUS"
