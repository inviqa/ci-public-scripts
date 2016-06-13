#!/bin/bash
HEM_ASSET_ENV="${HEM_ASSET_ENV:-development}"
HEM_RUN_ENV="${HEM_RUN_ENV:-local}"
ASSET_DB_USER="${ASSET_DB_USER:-magento}"
ASSET_DB_PASSWORD="${ASSET_DB_PASSWORD:-magento}"

export HEM_RUN_ENV

set -e

mkdir -p tools/assets

# Install hem as a gem in tools/assets if it's not already available in the
# project Gemfile
set +e
bundle show hem 2>&1 >/dev/null
RESULT=$?
set -e

pushd tools/assets >/dev/null
  if [ ${RESULT} -gt 0 ]; then
    cat <<- EOF > Gemfile
    source "https://rubygems.org"

    gem 'hem', '< 1.1'
EOF
    rm Gemfile.lock 2>/dev/null || true
    bundle install --path .gems
  fi

  # requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env variables to be present:
  bundle exec hem --non-interactive assets download "--env=${HEM_ASSET_ENV}"

  echo 'Importing database'

  bundle exec hem assets apply --force "--env=${HEM_ASSET_ENV}" $*

  for DB_ASSET in $(find "${HEM_ASSET_ENV}" -name '*.sql.gz'); 
  do
    DB_NAME="$(echo \"${DB_ASSET}\" | sed 's#.*/\([^/.]*\)[^\]*$#\1#')"
    echo "GRANT ALL ON ${DB_NAME}.* to '${ASSET_DB_USER}'@'%' IDENTIFIED BY '${ASSET_DB_PASSWORD}'" |  mysql -uroot
  done

  bundle exec hem magento initialize-vm
popd >/dev/null
