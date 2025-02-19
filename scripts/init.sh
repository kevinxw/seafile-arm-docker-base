#!/bin/bash

function print() {
    echo "[Init] $@"
}

function detectAutoMode() {
    if [[ "$SEAFILE_ADMIN_EMAIL" && "$SEAFILE_ADMIN_PASSWORD" ]]
    then
        print "Auto mode detected"
        # Note: it's not possible to just call the script with "auto"
        # and the server name in argument is never set anywhere thus
        # it's basically useless.
        # So just keep it that way and wait for fixes (if they happen)
        AUTO="auto -n useless"
    else
        print "Manual mode detected"
    fi
}

if [ "$SEAFILE_DIR" ] 
then
    print "Unsupported parameter: SEAFILE_DIR"
    exit 1
fi

print "Setting default environment"
if [ ! "$SERVER_IP" ]; then export SERVER_IP=127.0.0.1; fi
if [ "$PORT" ]; then export SERVER_IP=${SERVER_IP}:${PORT}; fi
if [ ! "$SEAHUB_PORT" ]; then export SEAHUB_PORT=8000; fi
if [ "$ENABLE_TLS" == "1" ]; then export HTTPS_SUFFIX="s"; fi
if [ ! "$MYSQL_HOST" ]; then export MYSQL_HOST=127.0.0.1; fi
if [ ! "$MYSQL_PORT" ]; then export MYSQL_PORT=3306; fi
if [ ! "$MYSQL_USER" ]; then export MYSQL_USER=seafile; fi
if [ ! "$MYSQL_USER_HOST" ]; then export MYSQL_USER_HOST="%"; fi

detectAutoMode
cd /opt/seafile

if [ "$AUTO" ]
then
    print "Waiting for db"
    /home/seafile/wait_for_db.sh
fi

if [ -d "/shared/media" ]
then
    print "Cleaning media folder"
    rm -rf /shared/media
fi

print "Exposing media folder in the volume"
cp -r ./media /shared/
ln -s /shared/media ./seafile-server-$SEAFILE_VERSION/seahub

print "Running installation script"
LOGFILE=./install.log
./seafile-server-$SEAFILE_VERSION/setup-seafile-mysql.sh $AUTO |& tee $LOGFILE

# Handle db starting twice at init edge case 
if [[ "$AUTO" && "$(grep -Pi '(failed)|(error)' $LOGFILE)" ]]
then
    print "Installation failed. Maybe the db wasn't really ready?"

    print "Cleaning failed configuration"
    rm -rf ./conf
    rm -rf ./ccnet

    print "Waiting for db... again"
    /home/seafile/wait_for_db.sh

    print "Retrying install"
    ./seafile-server-$SEAFILE_VERSION/setup-seafile-mysql.sh $AUTO | tee $LOGFILE
fi

if [ "$(grep -Pi '(failed)|(error)|(missing)' $LOGFILE)" ]
then
    print "Something went wrong"
    exit 1
fi

print "Properly expose avatars and custom assets"
rm -rf /shared/media/avatars
ln -s ../seahub-data/avatars /shared/media
ln -s ../seahub-data/custom /shared/media

print "Exposing configuration and data"
cp -r ./conf /shared/ && rm -rf ./conf
cp -r ./seafile-data /shared/ && rm -rf ./seafile-data
cp -r ./seahub-data /shared/ && rm -rf ./seahub-data
mkdir /shared/logs
mkdir /shared/seahub-data/custom

if [ ! -d "./seafile-server-latest" ]
then
    print "Making symlink to latest version"
    ln -s seafile-server-$SEAFILE_VERSION seafile-server-latest
fi

if [ ! -d "./conf" ]
then
    print "Linking internal configuration and data folders with the volume"
    ln -s /shared/conf .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
fi

if [ "$AUTO" ]
then
    print "Setting admin credentials"
    echo "{\"email\":\"$SEAFILE_ADMIN_EMAIL\", \"password\":\"$SEAFILE_ADMIN_PASSWORD\"}" > ./conf/admin.txt

    print "Writing configuration"
    /home/seafile/write_config.sh
fi

print "Done"
