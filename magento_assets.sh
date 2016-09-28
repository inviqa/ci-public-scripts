#!/bin/bash
HEM_ASSET_ENV="${HEM_ASSET_ENV:-development}"
HEM_RUN_ENV="${HEM_RUN_ENV:-local}"
ASSET_DB_USER="${ASSET_DB_USER:-magento}"
ASSET_DB_PASSWORD="${ASSET_DB_PASSWORD:-magento}"

export HEM_RUN_ENV

set -e

mkdir -p tools/assets

# Uninstall hem as a gem if it's in the project Gemfile
# project Gemfile
set +e
bundle show hem 2>&1 >/dev/null
RESULT=$?
set -e

pushd tools/assets >/dev/null
  if [ ${RESULT} -eq 0 ]; then
    gem uninstall hem --all --executables --force
  fi

  wget -nc https://dx6pc3giz7k1r.cloudfront.net/repos/ubuntu/pool/main/h/hem/hem_1.2.4-1_amd64.deb
  sudo dpkg -i hem_1.2.4-1_amd64.deb

  # requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env variables to be present:
  hem --non-interactive assets download "--env=${HEM_ASSET_ENV}"

  echo 'Importing database'

  hem assets apply --force "--env=${HEM_ASSET_ENV}" $*

  for DB_ASSET in $(find "${HEM_ASSET_ENV}" -name '*.sql.gz'); 
  do
    DB_NAME="$(echo \"${DB_ASSET}\" | sed 's#.*/\([^/.]*\)[^\]*$#\1#')"
    echo "GRANT ALL ON ${DB_NAME}.* to '${ASSET_DB_USER}'@'%' IDENTIFIED BY '${ASSET_DB_PASSWORD}'" |  mysql -uroot
  done

  hem magento initialize-vm
popd >/dev/null
