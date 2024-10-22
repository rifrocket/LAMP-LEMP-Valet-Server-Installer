#!/bin/bash

#!/bin/bash

# Default values
mysql_pass="testT8080"
php_version="8.2"  # Default PHP version
install_lamp=true
install_lemp=false
install_valet=false
install_composer=false
install_supervisor=false
remove_web_server=false

# Show help message
show_help() {
  cat << EOF
Usage: install-lamp.sh [options]

Options:
  --lamp                    Install LAMP stack (Apache, MySQL, PHP)
  --lemp                    Install LEMP stack (Nginx, MySQL, PHP)
  --valet                   Install Valet Linux (Nginx, MySQL, PHP, Composer, Valet for Linux)
  
Customization Options:
  -p, --mysql-password       Set MySQL root password (default: testT8080)
  -v, --php-version          Specify PHP version to install (default: 8.2)
  -s, --supervisor           Install Supervisor (default: false)
  -c, --composer             Install Composer (default: false)
  -r, --remove               Remove existing LAMP or LEMP stack
  -h, --help                 Show this help message

Examples:
  ./install-lamp.sh --lamp --php-version=8.2
  ./install-lamp.sh --lemp --php-version=8.2 --mysql-password=mysecurepassword
  
EOF
}

# Parse arguments
while [ "$1" != "" ]; do
  case "$1" in
    --lamp ) install_lamp=true; install_lemp=false; shift ;;
    --lemp ) install_lemp=true; install_lamp=false; shift ;;
    -p | --mysql-password ) mysql_pass="$2"; shift 2 ;;
    -v | --php-version ) php_version="$2"; shift 2 ;;
    -c | --composer ) install_composer=true; shift ;;
    -s | --supervisor ) install_supervisor=true; shift ;;
    -r | --remove ) remove_web_server=true; shift ;;
    -h | --help ) show_help; exit ;;
    --valet ) install_lemp=false; install_lamp=false; install_composer=false; install_valet=true; shift ;;

    * ) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done


# Get server IP
get_server_ip() {
  curl -s https://api.ipify.org || echo "localhost"
}
# Display completion message
DisplayCompletionMessage() {
  ip=$(get_server_ip)
  local stack=$1
  if [[ $stack == "Valet" ]]; then
    echo "+-------------------------------------------+"
    echo "| Valet Linux Stack Installed Successfully  |"
    echo "+-------------------------------------------+"
    echo "| Web Site: http://phpmyadmin.test/          "
    echo "| User: root || Pass: $mysql_pass            "
    echo "+-------------------------------------------+"
  else
    echo "+-------------------------------------------+"
    echo "|    $stack Stack Installed Successfully    |"
    echo "+-------------------------------------------+"
    echo "| Web Site: http://$ip/                "
    echo "| PhpMyAdmin: http://$ip/phpmyadmin    "
    echo "| User: root || Pass: $mysql_pass            "
    echo "+-------------------------------------------+"
  fi
}
# Check OS compatibility and root privileges
check_requirements() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Please run this script with sudo or as root."
    exit 1
  fi

  if ! command -v lsb_release > /dev/null; then
    echo "ERROR: lsb_release command not found. This script only supports Ubuntu and Debian."
    exit 1
  fi

  os_name=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
  if [[ "$os_name" != "ubuntu" && "$os_name" != "debian" ]]; then
    echo "ERROR: This script only supports Ubuntu and Debian."
    exit 1
  fi

  if [[ "$os_name" == "ubuntu" ]]; then
    os_version=$(lsb_release -rs)
    if (( $(echo "$os_version < 20" | bc -l) )); then
      echo "ERROR: This script requires Ubuntu 20 or higher."
      exit 1
    fi
  fi
}


# Check if Apache, MySQL, and PHP are installed
is_lamp_installed() {
  apache_status=$(systemctl is-active apache2)
  mysql_status=$(systemctl is-active mysql)
  php_installed=$(php --version 2>/dev/null)

  if [[ "$apache_status" == "active" && "$mysql_status" == "active" && -n "$php_installed" ]]; then
    return 0  # LAMP is installed
  else
    return 1  # LAMP is not installed
  fi
}

is_lemp_installed() {
  nginx_status=$(systemctl is-active nginx)
  mysql_status=$(systemctl is-active mysql)
  php_installed=$(php --version 2>/dev/null)

  if [[ "$nginx_status" == "active" && "$mysql_status" == "active" && -n "$php_installed" ]]; then
    return 0  # LEMP is installed
  else
    return 1  # LEMP is not installed
  fi
}

is_valet_installed() {
  nginx_status=$(systemctl is-active nginx)
  mysql_status=$(systemctl is-active mysql)
  php_installed=$(php --version 2>/dev/null)
  composer_installed=$(composer --version 2>/dev/null)
  valet_installed=$(valet --version 2>/dev/null)

  if [[ "$nginx_status" == "active" && "$mysql_status" == "active" && -n "$php_installed" && -n "$composer_installed" && -n "$valet_installed" ]]; then
    return 0  # Valet is installed
  else
    return 1  # Valet is not installed
  fi
}

# Update system packages
update_system() {
  echo "+--------------------------------------+"
  echo "|     Updating system packages         |"
  echo "+--------------------------------------+"
  sudo systemctl daemon-reload
  sudo apt update -qq
  sudo snap -y remove curl
  sudo apt install -y curl
  sudo apt install -y openssh-client
  sudo apt install -y unzip
  sudo systemctl daemon-reload
  echo "+--------------------------------------+"
  echo "|     System packages updated          |"
  echo "+--------------------------------------+"
}

# Add PHP repository based on OS
add_php_repository() {
  echo "+--------------------------------------+"
  echo "|     Adding PHP Repository            |"
  echo "+--------------------------------------+"

  os_name=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
  os_version=$(lsb_release -cs)

  if [[ "$os_name" == "ubuntu" ]]; then
    if ! grep -q "^deb .*$os_version.*ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
      sudo apt install -y software-properties-common
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install software-properties-common."
        exit 1
      fi

      sudo add-apt-repository -y ppa:ondrej/php
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to add PHP repository."
        exit 1
      fi

      sudo apt update
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to update package list."
        exit 1
      fi
    else
      echo "PHP repository already added. Skipping..."
    fi
  elif [[ "$os_name" == "debian" ]]; then
    if ! grep -q "^deb .*sury.org/php" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
      sudo apt install -y apt-transport-https lsb-release ca-certificates curl
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install required packages."
        exit 1
      fi

      curl -fsSL https://packages.sury.org/php/README.txt | sudo bash -x
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to add PHP repository."
        exit 1
      fi

      sudo apt update
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to update package list."
        exit 1
      fi
    else
      echo "PHP repository already added. Skipping..."
    fi
  else
    echo "Unsupported OS: $os_name"
    exit 1
  fi

  echo "+--------------------------------------+"
  echo "|   PHP Repository Added Successfully  |"
  echo "+--------------------------------------+"
}

# Install PHP and required extensions
install_php() {
  local php_version=$1
  echo "+--------------------------------------+"
  echo "|     Installing PHP $php_version      |"
  echo "+--------------------------------------+"

  # Add the PHP repository before installation
  add_php_repository

  sudo apt install -y \
    php$php_version-fpm \
    php$php_version-cli \
    php$php_version-zip \
    php$php_version-gd \
    php$php_version-common \
    php$php_version-xml \
    php$php_version-bcmath \
    php$php_version-tokenizer \
    php$php_version-mbstring \
    php$php_version-curl \
    php$php_version-xmlrpc \
    php$php_version-mysql \
    php$php_version-ldap 

  sudo update-alternatives --set php /usr/bin/php$php_version
  echo "+--------------------------------------+"
  echo "|    PHP $php_version Installed        |"
  echo "+--------------------------------------+"
}


# Install Apache
install_apache() {
  local php_version=$1
  echo "+--------------------------------------+"
  echo "|     Installing Apache                |"
  echo "+--------------------------------------+"
  sudo DEBIAN_FRONTEND=noninteractive  apt install -y libapache2-mod-php$php_version
  sudo apt install -y apache2 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Apache."
    exit 1
  fi

  sudo ufw allow in "Apache Full"

  sudo systemctl start apache2 && sudo systemctl enable apache2
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start or enable Apache."
    exit 1
  fi

  sudo apache2ctl configtest
  if [ $? -ne 0 ]; then
    echo "ERROR: Apache configuration test failed."
    exit 1
  fi

  # Enable PHP module and restart the web server
  sudo a2enmod php$php_version
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to enable PHP module."
    exit 1
  fi

  sudo systemctl restart apache2
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to restart Apache."
    exit 1
  fi

  echo "+--------------------------------------+"
  echo "|     Apache Installed Successfully    |"
  echo "+--------------------------------------+"
}

# Install Nginx
install_nginx() {
  echo "+--------------------------------------+"
  echo "|     Installing Nginx                 |"
  echo "+--------------------------------------+"
  sudo apt install -y nginx > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Nginx."
    exit 1
  fi

  sudo ufw allow "Nginx Full"
  sudo systemctl enable nginx && sudo systemctl start nginx
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to enable or start Nginx."
    exit 1
  fi

  sudo systemctl restart nginx
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to restart Nginx."
    exit 1
  fi

  echo "+--------------------------------------+"
  echo "|  Nginx installed and configured      |"
  echo "+--------------------------------------+"
}

# Install Valet
install_valet() {
  echo "+--------------------------------------+"
  echo "|     Installing Valet                 |"
  echo "+--------------------------------------+"
  sudo add-apt-repository -y ppa:nginx/stable
  sudo apt update -qq
  composer global require cpriego/valet-linux
  valet install
  echo "+--------------------------------------+"
  echo "|  Valet Installed Successfully         |"
  echo "+--------------------------------------+"
}

# Install MySQL
install_mysql() {
  local pass=$1
  echo "+--------------------------------------+"
  echo "|     Installing MySQL                 |"
  echo "+--------------------------------------+"

  echo "mysql-server mysql-server/root_password password $pass" | sudo debconf-set-selections
  echo "mysql-server mysql-server/root_password_again password $pass" | sudo debconf-set-selections

  sudo apt install -y mysql-server > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install MySQL."
    exit 1
  fi

  sudo systemctl start mysql && sudo systemctl enable mysql
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start or enable MySQL."
    exit 1
  fi

  echo "+--------------------------------------+"
  echo "|    MySQL Installed Successfully      |"
  echo "+--------------------------------------+"
}



# Install phpMyAdmin
install_phpmyadmin() {
  local pass=$1
  local php_version=$2
  echo "+--------------------------------------+"
  echo "|     Installing PhpMyAdmin            |"
  echo "+--------------------------------------+"

  # Pre-configure debconf selections for non-interactive installation
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $pass" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $pass" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $pass" | sudo debconf-set-selections

  # Install phpMyAdmin
  sudo DEBIAN_FRONTEND=noninteractive apt -y install phpmyadmin
  sudo update-alternatives --set php /usr/bin/php$php_version
  # Remove existing symlink if it exists
  if [ -e /var/www/html/phpmyadmin ]; then
    echo "Existing phpMyAdmin directory found. Removing it..."
    sudo rm -rf /var/www/html/phpmyadmin
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to remove existing phpMyAdmin directory."
      exit 1
    fi
  fi

  # For Nginx configuration
  if command -v nginx > /dev/null 2>&1; then
      echo "Configuring phpMyAdmin for Nginx..."
      sudo ln -s /usr/share/phpmyadmin /var/www/html/
  
      # Set permissions for the phpMyAdmin directory
      sudo chown -R www-data:www-data /var/www/html/phpmyadmin
      sudo chmod -R 755 /var/www/html/phpmyadmin
  
      # Create Nginx configuration for phpMyAdmin
      NGINX_CONF="/etc/nginx/sites-available/default"
          cat <<EOL | sudo tee "$NGINX_CONF" > /dev/null
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name localhost;  # Replace with your server's domain or IP

    root /var/www/html;  # This should point to the parent directory of phpMyAdmin
    index index.php index.html index.htm;

    location /phpmyadmin {
        alias /var/www/html/phpmyadmin;  # Use alias for phpMyAdmin
        index index.php index.html index.htm;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php8.2-fpm.sock;  # Adjust PHP version as needed
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
        }
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\.ht {
        deny all;  # Deny access to .htaccess files
    }
}
EOL
    sudo phpenmod mbstring gettext
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    # Test and reload Nginx
    sudo nginx -t
    sudo systemctl reload nginx
    if [ $? -ne 0 ]; then
        echo "Nginx configuration test failed. Please check your settings."
        exit 1
    fi    
  fi

  # For Apache configuration
  if command -v apache2 > /dev/null 2>&1; then
    echo "Configuring phpMyAdmin for Apache..."
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
    sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
    sudo a2enconf phpmyadmin
    sudo phpenmod mbstring gettext
    sudo systemctl restart apache2
    sudo apache2ctl configtest
    if [ $? -eq 0 ]; then
      sudo systemctl reload apache2
    else
      echo "Apache2 configuration test failed. Please check your settings."
      exit 1
    fi
  fi

  # For Valet configuration
  if command -v valet > /dev/null 2>&1; then
    echo "Configuring phpMyAdmin for Valet..."
    sudo phpenmod mbstring zip curl
    cd /usr/share/phpmyadmin
    valet link phpmyadmin
    valet restart
  fi

  echo "+--------------------------------------+"
  echo "|  PhpMyAdmin Installed Successfully   |"
  echo "+--------------------------------------+"
}


# Install Supervisor
install_supervisor() {
  echo "+--------------------------------------+"
  echo "|     Installing Supervisor            |"
  echo "+--------------------------------------+"

  sudo apt install -y supervisor > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Supervisor."
    exit 1
  fi

  sudo systemctl start supervisor && sudo systemctl enable supervisor
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start or enable Supervisor."
    exit 1
  fi

  echo "+--------------------------------------+"
  echo "|  Supervisor Installed Successfully   |"
  echo "+--------------------------------------+"
}

# install Composer
install_composer() {
  echo "+--------------------------------------+"
  echo "|     Installing Composer              |"
  echo "+--------------------------------------+"
  cd ~
  curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download Composer installer."
    exit 1
  fi

  HASH=$(curl -sS https://composer.github.io/installer.sig)
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to retrieve Composer installer hash."
    exit 1
  fi

  echo $HASH
  php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); } echo PHP_EOL;"
  if [ $? -ne 0 ]; then
    echo "ERROR: Composer installer verification failed."
    exit 1
  fi

  sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Composer."
    exit 1
  fi

  echo "+--------------------------------------+"
  echo "|  Composer Installed Successfully     |"
  echo "+--------------------------------------+"
}

# Function to check if any ports are still in use by Apache, Nginx, MySQL
check_ports_and_processes() {
  echo "+--------------------------------------+"
  echo "|   Checking for Running Services      |"
  echo "+--------------------------------------+"

  # Check if any processes are still running on web server ports
  services=(80 443 3306)
  for port in "${services[@]}"; do
    if sudo lsof -i :$port > /dev/null; then
      echo "ERROR: Port $port is still in use. Killing processes..."
      sudo fuser -k $port/tcp
    else
      echo "Port $port is free."
    fi
  done

  # Check for any remaining broken installations
  echo "+--------------------------------------+"
  echo "|   Checking for Broken Installations  |"
  echo "+--------------------------------------+"
  sudo dpkg --configure -a
  sudo apt --fix-broken install
  sudo apt -y autoremove
  sudo apt -y autoclean

  echo "+--------------------------------------+"
  echo "|   System is Clean                    |"
  echo "+--------------------------------------+"
}

# Remove existing Apache, Nginx, MySQL, PHP, and phpMyAdmin
remove_existing_installation() {
  echo "+--------------------------------------------+"
  echo "|  Removing Existing Web Server Installation |"
  echo "+--------------------------------------------+"


  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $pass" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $pass" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $pass" | sudo debconf-set-selections
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
  

  # Stop and purge Apache if installed
  if command -v apache2 > /dev/null 2>&1; then
    echo "+--------------------------------------+"
    echo "|     Removing Apache                  |"
    echo "+--------------------------------------+"
    sudo systemctl stop apache2
    sudo DEBIAN_FRONTEND=noninteractive apt -y purge apache2 apache2-utils apache2-bin apache2.2-common
    sudo apt -y autoremove
    sudo apt -y autoclean
    sudo rm -rf /etc/apache2
    sudo rm -rf /var/log/apache2
    sudo rm -rf /etc/apache2/conf-enabled/phpmyadmin.conf
    sudo rm -rf /etc/apache2/conf-available/phpmyadmin.conf


  fi

  # Stop and purge Nginx if installed
  if command -v nginx > /dev/null 2>&1; then
    echo "+--------------------------------------+"
    echo "|     Removing Nginx                   |"
    echo "+--------------------------------------+"
    sudo systemctl stop nginx 
    sudo DEBIAN_FRONTEND=noninteractive apt -y purge nginx nginx-common nginx-full
    sudo apt -y autoremove
    sudo apt -y autoclean
    sudo rm -rf /etc/nginx /var/www/html /var/log/nginx
    sudo rm -rf /etc/nginx/sites-enabled/phpmyadmin.conf
    sudo rm -rf /etc/nginx/sites-available/phpmyadmin.conf

  fi

  # Stop and purge MySQL if installed
  if command -v mysql > /dev/null 2>&1; then
    echo "+--------------------------------------+"
    echo "|     Removing MySQL                   |"
    echo "+--------------------------------------+"
    sudo systemctl stop mysql
    sudo killall -9 mysqld  # Forcefully kill any remaining MySQL processes
    sudo DEBIAN_FRONTEND=noninteractive apt -y purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
    sudo apt -y autoremove
    sudo apt -y autoclean
    sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/run/mysqld
    sudo update-rc.d -f mysql remove
    sudo systemctl disable mysql
    sudo rm -rf /etc/systemd/system/mysql.service
  fi

  # Stop and purge PHP-FPM if installed
  if command -v php-fpm > /dev/null 2>&1; then
    echo "+--------------------------------------+"
    echo "|     Removing PHP-FPM                 |"
    echo "+--------------------------------------+"
    sudo systemctl stop php-fpm
    sudo DEBIAN_FRONTEND=noninteractive apt -y purge php-fpm
  fi
  echo "+--------------------------------------+"
  echo "|     Removing PHP                      |"
  echo "+--------------------------------------+"
  sudo DEBIAN_FRONTEND=noninteractive apt -y purge 'php*'    
  sudo apt -y autoremove
  sudo apt -y autoclean
  sudo rm -rf /etc/php /var/lib/php /var/log/php
  

  # Purge PHP and phpMyAdmin
  echo "+--------------------------------------+"
  echo "|     Removing phpMyAdmin              |"
  echo "+--------------------------------------+"
  sudo apt --fix-broken install
  sudo DEBIAN_FRONTEND=noninteractive apt -y purge phpmyadmin javascript-common libjs-popper.js libjs-bootstrap5
  sudo rm -rf /etc/phpmyadmin /var/lib/phpmyadmin /usr/share/phpmyadmin
  sudo apt -y autoremove
  sudo apt -y autoclean
  sudo dpkg --remove --force-remove-reinstreq javascript-common libjs-popper.js libjs-bootstrap5 phpmyadmin


  # Clean up
  echo "+--------------------------------------+"
  echo "|     Cleaning up                      |"
  echo "+--------------------------------------+"
  sudo apt -y autoremove
  sudo apt -y autoclean
  sudo apt clean
  unset DEBIAN_FRONTEND

  check_ports_and_processes
  echo "+--------------------------------------+"
  echo "|   Existing Installation Removed      |"
  echo "+--------------------------------------+"
}





# Run the installation steps
update_system

if $remove_web_server; then
  remove_existing_installation
fi

if [ "$install_lamp" = true ] && [ "$remove_web_server" = false ]; then
  check_requirements
  install_php $php_version
  install_apache $php_version
  install_mysql $mysql_pass
  install_phpmyadmin $mysql_pass $php_version
fi

if [ "$install_lemp" = true ] && [ "$remove_web_server" = false ]; then
  check_requirements
  install_php $php_version
  install_nginx
  install_mysql $mysql_pass
  install_phpmyadmin $mysql_pass $php_version
fi

if [ "$install_valet" = true ] && [ "$install_lemp" = false ] && [ "$install_lamp" = false ] && [ "$remove_web_server" = false ]; then
  check_requirements
  install_php $php_version
  install_mysql $mysql_pass  
  install_composer;
  install_valet
  install_phpmyadmin $mysql_pass $php_version
fi

if $install_composer; then
  install_composer
fi

if $install_supervisor; then
  install_supervisor
fi

# check if LEMP stack is installed
if ( is_lemp_installed || is_lamp_installed || is_valet_installed ) && [ "$remove_web_server" = false ]; then
  if [ "$install_lemp" = true ]; then
    DisplayCompletionMessage "LEMP"
  elif [ "$install_valet" = true ]; then
    DisplayCompletionMessage "Valet"
  else
    DisplayCompletionMessage "LAMP"
  fi
fi






