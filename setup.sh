#!/bin/bash

# WordPress Containerized Client Setup Script
# Installs WordPress core, configures database, and sets up required plugins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
CLEAN_INSTALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_INSTALL=true
            shift
            ;;
        --help)
            echo "WordPress Setup Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean    Clean existing WordPress installation before setup"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine environment from .env file
ENVIRONMENT="${ENVIRONMENT:-unknown}"
if [ -f ".env" ]; then
    ENVIRONMENT=$(grep "^ENVIRONMENT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

# Safety check - prevent re-running setup for same environment
if [ -f ".setup-complete-${ENVIRONMENT}" ]; then
    log_warn "Setup already completed for ${ENVIRONMENT} environment."
    
    if [ "$CLEAN_INSTALL" = true ]; then
        log_warn "Clean install requested, but setup has already been completed."
        echo ""
        echo "This will:"
        echo "  - Stop and remove containers"
        echo "  - Delete all WordPress files"
        echo "  - Remove database data"
        echo "  - Reset setup completion status"
        echo ""
        read -p "Are you sure you want to continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Clean install cancelled"
            exit 0
        fi
        log_info "Proceeding with clean install..."
    else
        log_info "If you need to re-run setup for this environment, use: ./setup.sh --clean"
        exit 0
    fi
fi

log_info "Starting WordPress client setup..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    if [ -f ".env.template" ]; then
        log_info "Creating .env from template..."
        cp .env.template .env
        log_warn "Please edit .env file with your configuration before continuing."
        log_info "Press Enter when ready to continue..."
        read -r
    else
        log_error ".env file not found and no template available."
        exit 1
    fi
fi

# Load environment variables
set -a
source .env
set +a

# Validate required environment variables
REQUIRED_VARS=(
    "ENVIRONMENT"
    "MYSQL_DATABASE"
    "MYSQL_USER"
    "MYSQL_PASSWORD"
    "MYSQL_ROOT_PASSWORD"
    "WP_DOMAIN"
    "WP_TITLE"
    "WP_ADMIN_USER"
    "WP_ADMIN_PASSWORD"
    "WP_ADMIN_EMAIL"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable $var is not set in .env file"
        exit 1
    fi
done

# Set WordPress path and container names
WP_PATH="${DOCUMENT_ROOT:-./public_html}"
WEBSERVER_CONTAINER="${CONTAINER_PREFIX:-client}-webserver-${ENVIRONMENT:-staging}"
DATABASE_CONTAINER="${CONTAINER_PREFIX:-client}-mysql-${ENVIRONMENT:-staging}"

log_info "WordPress will be installed to: $WP_PATH"
log_info "Environment: $ENVIRONMENT"

# Clean installation if requested
if [ "$CLEAN_INSTALL" = true ]; then
    log_warn "Cleaning existing WordPress installation..."
    
    # Stop containers
    docker-compose down 2>/dev/null || true
    
    # Remove WordPress files
    rm -rf "$WP_PATH"/*
    rm -rf "$WP_PATH"/.??*  # Hidden files
    
    # Remove setup completion flags
    rm -f .setup-complete-*
    
    # Remove generated files
    rm -f settings.js
    
    # Remove Docker volumes (database data)
    docker volume rm $(docker volume ls -q --filter name="${CLIENT_NAME:-client}") 2>/dev/null || true
    
    log_info "Clean installation completed - all previous data removed"
fi

# Create WordPress directory if it doesn't exist
mkdir -p "$WP_PATH"

# Check if WordPress is already fully installed
WORDPRESS_INSTALLED=false
if [ -f "$WP_PATH/wp-config.php" ]; then
    # Check if WordPress database is actually set up
    if docker exec "$WEBSERVER_CONTAINER" wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
        log_warn "WordPress is already fully installed"
        log_info "Skipping WordPress installation..."
        WORDPRESS_INSTALLED=true
    else
        log_warn "WordPress files exist but installation is incomplete"
        log_info "Completing WordPress installation..."
    fi
fi

if [ "$WORDPRESS_INSTALLED" = false ]; then
    log_info "Starting Docker containers..."
    
    # Start containers first
    docker-compose up -d
    
    # Wait for containers to be ready
    log_info "Waiting for containers to start..."
    sleep 10
    
    # Wait for database to be ready
    log_info "Waiting for database connection..."
    max_attempts=30
    attempt=1
    
    while ! docker exec "$DATABASE_CONTAINER" mysqladmin ping -h localhost --silent 2>/dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            log_error "Database failed to start after $max_attempts attempts"
            exit 1
        fi
        log_info "Attempt $attempt/$max_attempts: Waiting for database..."
        sleep 5
        ((attempt++))
    done

    log_info "Database is ready"

    # Wait a bit longer for MySQL to be fully initialized
    log_info "Waiting for MySQL to be fully ready..."
    sleep 10

    # Test MySQL readiness with a simple query
    max_attempts=10
    attempt=1
    while ! MYSQL_PWD="$MYSQL_ROOT_PASSWORD" docker exec "$DATABASE_CONTAINER" mysql -u root -e "SELECT 1;" >/dev/null 2>&1; do
        if [ $attempt -eq $max_attempts ]; then
            log_error "MySQL is not responding to queries after $max_attempts attempts"
            exit 1
        fi
        log_info "MySQL query test $attempt/$max_attempts..."
        sleep 5
        ((attempt++))
    done

    log_info "MySQL is fully ready for queries"

    # Ensure WordPress user exists (MySQL may not have created it)
    log_info "Creating WordPress database user..."
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" docker exec "$DATABASE_CONTAINER" mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;" || log_error "Database creation failed"
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" docker exec "$DATABASE_CONTAINER" mysql -u root -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" || log_error "User creation failed"
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" docker exec "$DATABASE_CONTAINER" mysql -u root -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';" || log_error "Permission grant failed"
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" docker exec "$DATABASE_CONTAINER" mysql -u root -e "FLUSH PRIVILEGES;" || log_error "Privilege flush failed"

    # Download WordPress core
    log_info "Downloading WordPress core..."
    docker exec "$WEBSERVER_CONTAINER" wp core download --path=/var/www/html --allow-root

    # Generate wp-config.php using WP-CLI
    log_info "Creating WordPress configuration..."
    docker exec "$WEBSERVER_CONTAINER" wp config create \
        --path=/var/www/html \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="$MYSQL_HOST" \
        --allow-root
    log_info "wp-config.php generated by WP-CLI"

    # Install WordPress (this is what was failing before)
    log_info "Installing WordPress..."
    docker exec "$WEBSERVER_CONTAINER" wp core install \
        --path=/var/www/html \
        --url="$WP_DOMAIN" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root

    log_info "WordPress core installation completed"
fi

# Ensure containers are running for plugin installation
log_info "Ensuring containers are running..."
docker-compose up -d

# Install and configure plugins
log_info "Installing required plugins..."

# Install other plugins
PLUGINS=(
    "classic-editor"
    "wp-super-cache"
    "civicrm"
    "acf-pro"
)

for plugin in "${PLUGINS[@]}"; do
    if ! docker exec "$WEBSERVER_CONTAINER" wp plugin is-installed "$plugin" --path=/var/www/html --allow-root 2>/dev/null; then
        log_info "Installing plugin: $plugin"
        docker exec "$WEBSERVER_CONTAINER" wp plugin install "$plugin" --activate --path=/var/www/html --allow-root
    else
        log_info "Plugin already installed: $plugin"
    fi
done

# Configure WordPress settings
log_info "Configuring WordPress settings..."

# Set timezone
if [ -n "${WP_TIMEZONE:-}" ]; then
    docker exec "$WEBSERVER_CONTAINER" wp option update timezone_string "$WP_TIMEZONE" --path=/var/www/html --allow-root
fi

# Set permalink structure
docker exec "$WEBSERVER_CONTAINER" wp rewrite structure '/%postname%/' --path=/var/www/html --allow-root

# Update default options
docker exec "$WEBSERVER_CONTAINER" wp option update start_of_week 1 --path=/var/www/html --allow-root  # Monday
docker exec "$WEBSERVER_CONTAINER" wp option update date_format 'F j, Y' --path=/var/www/html --allow-root
docker exec "$WEBSERVER_CONTAINER" wp option update time_format 'g:i a' --path=/var/www/html --allow-root

# Remove default content (optional)
if [ "${REMOVE_DEFAULT_CONTENT:-true}" = "true" ]; then
    log_info "Removing default WordPress content..."
    docker exec "$WEBSERVER_CONTAINER" wp post delete 1 --force --path=/var/www/html --allow-root 2>/dev/null || true  # Hello World post
    docker exec "$WEBSERVER_CONTAINER" wp post delete 2 --force --path=/var/www/html --allow-root 2>/dev/null || true  # Sample page
    docker exec "$WEBSERVER_CONTAINER" wp comment delete 1 --force --path=/var/www/html --allow-root 2>/dev/null || true  # Default comment
fi

# Set file permissions
log_info "Setting file permissions..."
docker exec "$WEBSERVER_CONTAINER" chown -R www-data:www-data /var/www/html
docker exec "$WEBSERVER_CONTAINER" find /var/www/html -type d -exec chmod 755 {} \;
docker exec "$WEBSERVER_CONTAINER" find /var/www/html -type f -exec chmod 644 {} \;
docker exec "$WEBSERVER_CONTAINER" chmod 600 /var/www/html/wp-config.php

# Fix wp-config.php for reverse proxy HTTPS detection
log_info "Configuring WordPress for reverse proxy..."
docker exec "$WEBSERVER_CONTAINER" sed -i "/\/\* That's all, stop editing/i\\
// Fix for Traefik reverse proxy HTTPS detection\\
if ( isset( \\\$_SERVER['HTTP_X_FORWARDED_PROTO'] ) && \\\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {\\
    \\\$_SERVER['HTTPS']='on';\\
}" /var/www/html/wp-config.php

# Install Node.js dependencies and run build
log_info "Setting up build configuration..."
if [ -f "settings.template.js" ]; then
    envsubst < settings.template.js > settings.js
    log_info "Generated settings.js from template"
else
    log_warn "settings.template.js not found - build system may not work correctly"
fi

log_info "Installing Node.js dependencies and building theme..."
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    npm install
    npm run production
    log_info "Theme build completed"
else
    log_warn "npm not found or package.json missing - skipping theme build"
fi

# Mark setup as complete for this environment
log_info "Finalizing setup for ${ENVIRONMENT} environment..."
touch ".setup-complete-${ENVIRONMENT}"

# Remove template files for security (setup script preserved for other environments)
if [ -f ".env.template" ]; then
    rm .env.template
    log_info "Removed .env.template"
fi

if [ -f "settings.template.js" ]; then
    rm settings.template.js
    log_info "Removed settings.template.js"
fi

log_info "========================================="
log_info "WordPress setup completed for ${ENVIRONMENT}!"
log_info "========================================="
log_info "Environment: $ENVIRONMENT"
log_info "WordPress URL: https://$WP_DOMAIN"
log_info "Admin URL: https://$WP_DOMAIN/wp-admin/"
log_info "Admin User: $WP_ADMIN_USER"
log_info "Container Status:"
docker ps --filter "name=${CONTAINER_PREFIX:-client}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
log_info "========================================="
log_info "Setup script preserved for other environments."
log_info "Your ${ENVIRONMENT} WordPress site is ready!"