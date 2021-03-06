#!/bin/bash

if [ -z "$(ls -A /opt/nagios/etc)" ]; then
    echo "Started with emty ETC, copying example data in-place"
    cp -Rp /orig/etc/* /opt/nagios/etc/
fi

if [ -z "$(ls -A /opt/nagios/var)" ]; then
    echo "Started with emty VAR, copying example data in-place"
    cp -Rp /orig/var/* /opt/nagios/var/
fi

if [ ! -f ${NAGIOS_HOME}/etc/htpasswd.users ] ; then
  htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS}
  chown -R nagios.nagios ${NAGIOS_HOME}/etc/htpasswd.users
fi

shutdown() {
  echo Shutting Down
  ls /etc/service | SHELL=/bin/sh parallel --no-notice sv force-stop {}
  if [ -e /proc/$RUNSVDIR ]; then
    kill -HUP $RUNSVDIR
    wait $RUNSVDIR
  fi

  # give stuff a bit of time to finish
  sleep 1

  ORPHANS=`ps -eo pid | grep -v PID  | tr -d ' ' | grep -v '^1$'`
  SHELL=/bin/bash parallel --no-notice 'timeout 5 /bin/bash -c "kill {} && wait {}" || kill -9 {}' ::: $ORPHANS 2> /dev/null
  exit
}
/bin/mkdir -p /var/run/pdagent
python /usr/share/pdagent/bin/pdagentd.py
sed -i "s/SERVICE/$SERVICE/g" /opt/nagios/etc/objects/contacts.cfg
sed -i "s/KEY_CRITICAL/$KEY_CRITICAL/g" /opt/nagios/etc/objects/contacts.cfg
sed -i "s/KEY_WARNING/$KEY_WARNING/g" /opt/nagios/etc/objects/contacts.cfg
exec runsvdir -P /etc/service &
RUNSVDIR=$!
echo "Started runsvdir, PID is $RUNSVDIR"
mkdir -p /var/run/sshd
sed -i 's/#PasswordAuthentication/PasswordAuthentication/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin\ prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
/usr/sbin/sshd
echo "root:$PWD_ROOT" | chpasswd
trap shutdown SIGTERM SIGHUP SIGINT
wait $RUNSVDIR

shutdown

