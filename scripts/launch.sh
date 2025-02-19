#!/bin/bash

function print() {
    echo "[Launch] $@"
}

cd /opt/seafile

if [ ! -d "./seafile-server-latest" ]
then
    print "Making symlink to latest version"
    ln -s seafile-server-$SEAFILE_VERSION seafile-server-latest
fi

if [[ ! -f "/shared/media/version" || "$(cat /shared/media/version)" != "$SEAFILE_VERSION" ]]
then
    print "Removing outdated media folder"
    rm -rf /shared/media/*

    print "Exposing new media folder in the volume"
    cp -r ./media /shared/

    print "Properly expose avatars and custom assets"
    rm -rf /shared/media/avatars
    ln -s ../seahub-data/avatars /shared/media
    ln -s ../seahub-data/custom /shared/media
fi

if [ ! -d "./conf" ]
then
    print "Linking internal configuration and data folders with the volume"
    ln -s /shared/conf .
    mkdir ccnet # Totally useless but still needed for the server to launch
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
    ln -s /shared/media ./seafile-server-latest/seahub
fi

print "Launching seafile"
./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

print "Done"
