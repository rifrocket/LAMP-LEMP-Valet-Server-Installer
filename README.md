
# LAMP/LEMP Stack Installation Script

This bash script automates the installation of a LAMP or LEMP stack on a DigitalOcean droplet or Ubuntu server. It includes options for installing various additional components like Valet, Composer, and Supervisor.

## Features
- LAMP stack installation (Linux, Apache, MySQL, PHP)
- LEMP stack installation (Linux, Nginx, MySQL, PHP)
- Optional installation of phpMyAdmin, Valet, Composer, and Supervisor
- Support for custom PHP versions
- Automatic configuration for MySQL and web servers
- Ability to remove existing web servers

## Requirements
- Ubuntu server (compatible with Ubuntu versions < 22)
- Root or sudo access

## Installation

Run the following one-liner on your server to automatically download and execute the script:

```bash
wget --no-check-certificate -O /tmp/install-lamp.sh https://raw.githubusercontent.com/rifrocket/LAMP-LEMP-Valet-Server-Installer/main/install-lamp.sh; sudo bash /tmp/install-lamp.sh --composer
```

Alternatively:

1. Upload the `install-lamp.sh` script to your server.
2. Make the script executable:
    ```bash
    chmod +x install-lamp.sh
    ```
3. Run the script with desired options:
    ```bash
    sudo ./install-lamp.sh [options]
    ```

## Usage

### Options:
- `--lamp`: Install the LAMP stack (Apache, MySQL, PHP).
- `--lemp`: Install the LEMP stack (Nginx, MySQL, PHP).
- `--valet`: Install Valet.
- `--composer`: Install Composer.
- `--supervisor`: Install Supervisor.
- `--php-version=<version>`: Specify a PHP version to install (default is PHP 8.2).
- `--phpmyadmin`: Install phpMyAdmin.
- `--remove`: Remove existing Apache or Nginx installations before proceeding.
  
### Example Commands:

- Install the LAMP stack:
    ```bash
    sudo ./install-lamp.sh --lamp
    ```

- Install the LEMP stack with PHP 8.1:
    ```bash
    sudo ./install-lamp.sh --lemp --php-version=8.1
    ```

- Install LAMP with phpMyAdmin and Composer:
    ```bash
    sudo ./install-lamp.sh --lamp  --composer
    ```

- Remove existing web servers:
    ```bash
    sudo ./install-lamp.sh  --remove
    ```
- Set MySQL password:
    ```bash
    sudo ./install-lamp.sh --lemp  --mysql-password=<your mysql password>
    ```
## Notes
- The script is specifically designed for Ubuntu servers and may not be compatible with other distributions.
- Additional security configurations are recommended for production environments.
- Ensure strong passwords are used during MySQL setup for enhanced security.
- The script can be customized further by modifying the default options at the top of the script.
