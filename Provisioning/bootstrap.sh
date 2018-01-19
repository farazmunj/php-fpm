#!/usr/bin/env bash


export UPDATE_SYSTEM=0
TIME_ZONE_FILE=/usr/share/zoneinfo/Europe/London

# ===================================================================
# Pretify logging to screen
# ===================================================================
printLog() {
  printf "[${VAGRANT_HOST}-bootstrap] $1\n";
}

installComposer() {
	printLog "Install GIT"
	sudo yum --quiet -y install git
	if [[ -s /var/www/html/application/composer.json ]] ;then
	  cd /var/www/html/ || return;
	  printLog "Installing Composer for PHP package management"
	  curl --silent https://getcomposer.org/installer | php
	  sudo COMPOSER=./application/composer.json php composer.phar install --quiet --prefer-dist > /dev/null
	  cd ~ || exit;
	fi
}

installMysql(){
	printLog "Installing DB";
	sudo yum --quiet -y install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
	if [[ $1 -eq 57 ]];then
		# -------------config for  mysql 5.7
		sudo yum --quiet -y install Percona-Server-server-57
		printLog "Start mysql server";	
		sudo systemctl start mysql
		printLog "Precona password";
		cat /var/log/mysqld.log | grep root@localhost: > ~/_last
		awk 'NF>1{print $NF}' ~/_last > ~/precona.password
		mysql -u root -p`cat ~/precona.password` -e "alter user 'root'@'localhost' identified by 'RootPw90$' " --connect-expired-password
		mysql -u root -p'RootPw90$' -e "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''))"
		
		rm ~/_last
		rm ~/precona.password
	fi
	if [[ $1 -eq 56 ]];then
		#--------------config for mysql 5.6
		sudo yum --quiet -y install Percona-Server-server-56
		printLog "Start mysql server";	
		sudo systemctl start mysql
		mysql -u root -e  "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('RootPw90$') "
	fi

}

importDB(){
	printLog "Import DB";
	mysqldump --host 192.168.16.124 --user=kohana_core --password=nokia8210 --routines kohana_core > kohana_core.sql
	mysqldump --host 192.168.16.124 --user=kohana_core --password=nokia8210 --routines sub178 > kohana.sql

	mysql -u root -p'RootPw90$' -e "create database kohana_core"
	mysql -u root -p'RootPw90$' -e "create database sub178"

	mysql -u root -p'RootPw90$' -e "create user 'kohana_core'@'localhost' identified by 'Nokia82!0' "
	mysql -u root -p'RootPw90$' -e "create user 'kohana_core'@'%' identified by 'Nokia82!0' "
	mysql -u root -p'RootPw90$' -e "create user 'sub178'@'localhost' identified by 'Nokia82!0' "
	mysql -u root -p'RootPw90$' -e "create user 'sub178'@'%' identified by 'Nokia82!0' "

	mysql -u root -p'RootPw90$' -e "GRANT ALL PRIVILEGES on * . * to 'kohana_core'@'localhost' "
	mysql -u root -p'RootPw90$' -e "GRANT ALL PRIVILEGES on * . * to 'kohana_core'@'%' "
	mysql -u root -p'RootPw90$' -e "GRANT ALL PRIVILEGES on sub178 . * to 'sub178'@'localhost' "
	mysql -u root -p'RootPw90$' -e "GRANT ALL PRIVILEGES on sub178 . * to 'sub178'@'%' "

	mysql --host localhost --user=root --password='RootPw90$' kohana_core < kohana_core.sql
	mysql --host localhost --user=root --password='RootPw90$' sub178 < kohana.sql
}

installPHP(){
	sudo rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

	printLog "Install HTTPD"
	sudo yum --quiet -y install httpd 

	printLog "Install PHP"
	sudo yum --quiet -y install php56w php56w-devel php56w-gd php56w-mbstring php56w-mysqlnd php56w-common
	sudo yum --quiet -y install php56w-mcrypt*
	sudo yum --quiet -y install php56w-pecl-apcu
	sudo yum --quiet -y install php56w-soap
	sudo yum --quiet -y install php56w-xml
	sudo yum --quiet -y install php56w-intl

	printLog "SetEnv"
	sudo echo 'SetEnv KOMMAND_ENV DEVELOPMENT
<Directory "/var/www/html">
	AllowOverride "All"
	Options SymLinksIfOwnerMatch
	Require all granted
	Order allow,deny
	Allow from all
</Directory>'  > /etc/httpd/conf.d/foo.conf
}

installPHPRemi(){
	#Command to install the Remi repository configuration package:
	sudo yum --quiet -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
	#Command to install the yum-utils package (for the yum-config-manager command):
	sudo yum --quiet -y install yum-utils
	
	#Command to enable the repository:
	sudo  yum-config-manager --enable remi-php71
	
	sudo yum --quiet -y update
	
	printLog "Install PHP"
	sudo yum --quiet -y install php php-gd php-mysqlnd php-mcrypt php-mbstring php-common php-pecl-apcu php-soap php-xml php-pecl-http php-devel php-intl php-pecl-zip php-fpm
	printLog "SetEnv"
	sudo echo 'SetEnv KOMMAND_ENV DEVELOPMENT
<VirtualHost *:80>
    #ServerNamekommand.me
    #ServerAlias*
    #gettheservernamefromtheHost:header
    UseCanonicalName Off
    #includetheservernameinthefilenamesusedtosatisfyrequests
    VirtualDocumentRoot "/var/www/vhosts/%0/httpdocs"
    #RewriteEngine On
    #RewriteCond %{HTTP_HOST} !^www\.[NC]
    #RewriteCond %{HTTPS} off
    #RewriteRule .*http://www.%{HTTP_HOST}$0 [R=301,L]
    #RewriteCond %{HTTP_HOST} !^www\.[NC]
    #RewriteCond %{HTTPS} on
    #RewriteRule .*https://www.%{HTTP_HOST}$0 [R=301,L]
    <Directory "/var/www/vhosts/*/httpdocs">
        AllowOverride "All"
        Options SymLinksIfOwnerMatch 
        Options -Includes -ExecCGI	
        Require all granted
        Order allow,deny
        Allow from all
        <IfModule mod_proxy_fcgi.c>
	    <Files ~ (\.php$)>
        	#SetHandler proxy:unix:/var/www/vhosts/socket/my.sock|fcgi://127.0.0.1:9000
        	SetHandler "proxy:fcgi://127.0.0.1:9000"
            </Files>
        </IfModule>
    </Directory>
</VirtualHost>'  > /etc/httpd/conf.d/foo.conf

}

printLog "Setting Timzone for host";
mv /etc/localtime /etc/localtime.orig
ln -s $TIME_ZONE_FILE /etc/localtime


printLog "Updating Environment";
printLog "ENABLE EPEL"
#Command to install the EPEL repository configuration package:
sudo yum --quiet -y install centos-release
sudo yum --quiet -y update
sudo yum --quiet -y install epel-release
sudo yum --quiet -y update

printLog "Install MC"
sudo yum --quiet -y install mc 
sudo yum --quiet -y install wget
#sudo yum --quiet -y install zip unzip

printLog "Setting document root to public directory"
mkdir /var/www/html/vendor
mkdir /var/www/html/cache
mkdir /var/www/html/logs


printLog "Change permissions"
sudo setenforce 0
#sudo chmod 777 /var/www/html -R
#sudo chcon -R -t httpd_sys_content_t /var/www/html/
#sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/cache
#sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/logs
#sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/img
#sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/vendor
sudo setsebool -P httpd_can_network_connect=1
sudo ln -s /var/www/html/application/.htaccess /var/www/html/.htaccess
# call functions to setup evniroment
#installPHP
installPHPRemi
#installComposer;
#installMysql 57;
#importDB;

#sudo echo "<?php defined('SYSPATH') or die('No direct script access.'); return array( 'id'=>1);" > /var/www/html/config/domain.php

printLog "Change permissions"
#sudo chown apache:apache /var/www/html -R

printLog "Restart apache";
sudo systemctl restart php-fpm
sudo systemctl restart httpd.service 
