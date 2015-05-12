FROM ubuntu:latest
 
MAINTAINER Alper Kucukural <alper.kucukural@umassmed.edu>
 
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get dist-upgrade
 
# Install apache, PHP, and supplimentary programs. curl and lynx-cur are for debugging the container.
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 libapache2-mod-php5 \
                    php5-mysqlnd php5-gd php-pear php-apc php5-curl curl lynx-cur mysql-server \
                    libreadline-dev libsqlite3-dev libbz2-dev libssl-dev python python-dev \
                    libmysqlclient-dev python-pip git expect default-jre r-base r-base-dev 

RUN pip install MySQL-python

# Enable apache mods.
RUN a2enmod php5
RUN a2enmod rewrite


# Update the PHP.ini file, enable <? ?> tags and quieten logging.
RUN sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php5/apache2/php.ini
RUN sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php5/apache2/php.ini
 
# Manually set up the apache environment variables
ENV PATH=$PATH:/usr/local/bin/dolphin-bin
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV DOLPHIN_PARAMS_SECTION=Docker


EXPOSE 80
EXPOSE 3306


#Install DESeq2 
RUN R -e 'source("http://bioconductor.org/biocLite.R"); biocLite("DESeq2");'



# Update the default apache site with the config we created.
ADD apache-config.conf /etc/apache2/sites-enabled/000-default.conf

RUN echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/fqdn.conf
RUN a2enconf fqdn
RUN echo "export DOLPHIN_PARAMS_SECTION="${DOLPHIN_PARAMS_SECTION} >> /etc/apache2/envvars

RUN echo 'Dolphin Docker 0.11'
ADD install-phpmyadmin.sh /tmp/install-phpmyadmin.sh
# Install phpMyAdmin
RUN chmod +x  /tmp/install-phpmyadmin.sh

RUN service mysql start \
    service apache2 start; \
    sleep 5; \
    /tmp/install-phpmyadmin.sh; \
    sleep 10; \ 
    zcat /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz|mysql -uroot

#RUN rm  /tmp/install-phpmyadmin.sh
RUN sed -i "s#// \$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#g" /etc/phpmyadmin/config.inc.php 
 
# Copy site into place.
ENV GITUSER=nephantes
ADD bin  /usr/local/bin
RUN git clone https://github.com/${GITUSER}/dolphin-bin /usr/local/bin/dolphin-bin
RUN cd /usr/local/bin/dolphin-bin/ZSI-2.1-a1 && python setup.py install
RUN git clone https://github.com/${GITUSER}/dolphin-webservice.git /var/www/html/dolphin_webservice
RUN git clone https://github.com/${GITUSER}/dolphin-tools /usr/local/share/dolphin_tools
RUN git clone https://github.com/${GITUSER}/dolphin-ui.git /var/www/html/dolphin
RUN chown -R www-data /var/www/html/dolphin
RUN chown -R www-data /var/www/html/dolphin_webservice
RUN chown -R www-data /usr/local/share/dolphin_tools

