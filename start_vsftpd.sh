#!/bin/sh

#Remove all ftp users
grep '/ftp/' /etc/passwd | cut -d':' -f1 | xargs -r -n1 deluser

#Create users
#USERS='name1|password1|[folder1][|uid1] name2|password2|[folder2][|uid2]'
#may be:
# user|password foo|bar|/home/foo
#OR
# user|password|/home/user/dir|10000
#OR
# user|password||10000

#Default user 'ftp' with password 'alpineftp'

if [ -z "$USERS" ]; then
  USERS="alpineftp|alpineftp"
fi

for i in $USERS ; do
  NAME=$(echo $i | cut -d'|' -f1)
  GROUP=$NAME
  PASS=$(echo $i | cut -d'|' -f2)
  FOLDER=$(echo $i | cut -d'|' -f3)
  UID=$(echo $i | cut -d'|' -f4)

  if [ -z "$FOLDER" ]; then
    FOLDER="/ftp/$NAME"
  fi

  if [ ! -z "$UID" ]; then
    UID_OPT="-u $UID"
    #Check if the group with the same ID already exists
    GROUP=$(getent group $UID | cut -d: -f1)
    if [ ! -z "$GROUP" ]; then
      GROUP_OPT="-G $GROUP"
    fi
  fi

  echo -e "$PASS\n$PASS" | adduser -h $FOLDER -s /sbin/nologin $UID_OPT $GROUP_OPT $NAME
  mkdir -p $FOLDER
  chown $NAME:$GROUP $FOLDER
  unset NAME PASS FOLDER UID
done


if [ -z "$MIN_PORT" ]; then
  MIN_PORT=21000
fi

if [ -z "$MAX_PORT" ]; then
  MAX_PORT=21010
fi

if [ ! -z "$ADDRESS" ]; then
  ADDR_OPT="-opasv_address=$ADDRESS"
fi


#Check for SSL support

echo "SSL = $SSL"
if [ "$SSL" = true ]; then
  CONF_FILE="vsftpd-ssl.conf"
  
  if [ ! -f "/certs/vsftp.key" ]; then
    mkdir -p /certs/

    echo "Setup RSA key .."

    echo "commonName              = localhost" >> /tmp/configfile

    openssl genrsa -out /certs/vsftp.key 4096
    openssl req -new -key /certs/vsftp.key -out /certs/vsftp.csr -config /openssl-config
    openssl x509 -req -days 3650 -in /certs/vsftp.csr -signkey /certs/vsftp.key -out /certs/vsftp.crt
    chmod 600 /certs/vsftp.key

    rm /openssl-config 2>/dev/null
  else
    echo "RSA key found"
  fi
else
  CONF_FILE="vsftpd.conf"
fi


# Used to run custom commands inside container
if [ ! -z "$1" ]; then
  exec "$@"
else
  vsftpd -opasv_min_port=$MIN_PORT -opasv_max_port=$MAX_PORT $ADDR_OPT /etc/vsftpd/$CONF_FILE
  [ -d /var/run/vsftpd ] || mkdir /var/run/vsftpd
  pgrep vsftpd | tail -n 1 > /var/run/vsftpd/vsftpd.pid
  exec pidproxy /var/run/vsftpd/vsftpd.pid true
fi

