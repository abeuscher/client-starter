#!/bin/bash

# WordPress Containerized Client Setup Script
# Installs WordPress core, configures database, and sets up required plugins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    log_info "If you need to re-run setup for this environment, delete .setup-complete-${ENVIRONMENT} file first."
    exit 0
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

# Set WordPress path
WP_PATH="${DOCUMENT_ROOT:-./public_html}"

log_info "WordPress will be installed to: $WP_PATH"

# Create WordPress directory if it doesn't exist
mkdir -p "$WP_PATH"

# Check if WordPress is already installed
if [ -f "$WP_PATH/wp-config.php" ]; then
    log_warn "WordPress already appears to be installed (wp-config.php exists)"
    log_info "Skipping WordPress installation..."
else
    log_info "Installing WP-CLI..."
    
    # Download and install WP-CLI if not present
    if ! command -v wp &> /dev/null; then
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
        log_info "WP-CLI installed successfully"
    else
        log_info "WP-CLI already installed"
    fi

    # Download WordPress core
    log_info "Downloading WordPress core..."
    wp core download --path="$WP_PATH" --allow-root

    # Create wp-config.php from template or generate new one
    log_info "Creating WordPress configuration..."
    if [ -f "wp-config-template.php" ]; then
        # Use template with environment variable substitution
        envsubst < wp-config-template.php > "$WP_PATH/wp-config.php"
        log_info "wp-config.php created from template"
    else
        # Generate wp-config.php using WP-CLI
        wp config create \
            --path="$WP_PATH" \
            --dbname="$MYSQL_DATABASE" \
            --dbuser="$MYSQL_USER" \
            --dbpass="$MYSQL_PASSWORD" \
            --dbhost="${MYSQL_HOST:-wardgreenhousesmysql}" \
            --allow-root
        log_info "wp-config.php generated"
    fi

    # Wait for database to be ready
    log_info "Waiting for database connection..."
    max_attempts=30
    attempt=1
    
    while ! wp db check --path="$WP_PATH" --allow-root 2>/dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            log_error "Database connection failed after $max_attempts attempts"
            exit 1
        fi
        log_info "Attempt $attempt/$max_attempts: Waiting for database..."
        sleep 5
        ((attempt++))
    done

    log_info "Database connection established"

    # Install WordPress
    log_info "Installing WordPress..."
    wp core install \
        --path="$WP_PATH" \
        --url="$WP_DOMAIN" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root

    log_info "WordPress core installation completed"
fi

# Install and configure plugins
log_info "Installing required plugins..."

# Install ACF Pro (requires license key or manual upload)
if [ -n "${ACF_PRO_KEY:-}" ]; then
    log_info "Installing ACF Pro with license key..."
    # Note: ACF Pro installation with license key would require custom implementation
    log_warn "ACF Pro automatic installation not implemented - please install manually"
else
    log_warn "ACF Pro license key not provided - please install manually"
fi

# Install other plugins
PLUGINS=(
    "classic-editor"
    "wp-super-cache"
    "wordfence"
    "updraftplus"
)

for plugin in "${PLUGINS[@]}"; do
    if ! wp plugin is-installed "$plugin" --path="$WP_PATH" --allow-root; then
        log_info "Installing plugin: $plugin"
        wp plugin install "$plugin" --activate --path="$WP_PATH" --allow-root
    else
        log_info "Plugin already installed: $plugin"
    fi
done

# Configure WordPress settings
log_info "Configuring WordPress settings..."

# Set timezone
if [ -n "${WP_TIMEZONE:-}" ]; then
    wp option update timezone_string "$WP_TIMEZONE" --path="$WP_PATH" --allow-root
fi

# Set permalink structure
wp rewrite structure '/%postname%/' --path="$WP_PATH" --allow-root

# Update default options
wp option update start_of_week 1 --path="$WP_PATH" --allow-root  # Monday
wp option update date_format 'F j, Y' --path="$WP_PATH" --allow-root
wp option update time_format 'g:i a' --path="$WP_PATH" --allow-root

# Remove default content (optional)
if [ "${REMOVE_DEFAULT_CONTENT:-true}" = "true" ]; then
    log_info "Removing default WordPress content..."
    wp post delete 1 --force --path="$WP_PATH" --allow-root  # Hello World post
    wp post delete 2 --force --path="$WP_PATH" --allow-root  # Sample page
    wp comment delete 1 --force --path="$WP_PATH" --allow-root  # Default comment
fi

# Set file permissions
log_info "Setting file permissions..."
find "$WP_PATH" -type d -exec chmod 755 {} \;
find "$WP_PATH" -type f -exec chmod 644 {} \;
chmod 600 "$WP_PATH/wp-config.php"

# Run initial theme build
log_info "Building theme assets..."
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    npm run production
    log_info "Theme build completed"
else
    log_warn "npm not found or package.json missing - skipping theme build"
fi

# Mark setup as complete for this environment
log_info "Finalizing setup for ${ENVIRONMENT} environment..."
touch ".setup-complete-${ENVIRONMENT}"

# Remove template files for security (but keep setup script for other environments)
if [ -f ".env.template" ]; then
    rm .env.template
    log_info "Removed .env.template"
fi

if [ -f "wp-config-template.php" ]; then
    rm wp-config-template.php
    log_info "Removed wp-config-template.php"
fi

# Do NOT remove setup script - other environments may need it

log_info "========================================="
log_info "WordPress setup completed for ${ENVIRONMENT}!"
log_info "========================================="
log_info "Environment: $ENVIRONMENT"
log_info "WordPress URL: https://$WP_DOMAIN"
log_info "Admin URL: https://$WP_DOMAIN/wp-admin/"
log_info "Admin User: $WP_ADMIN_USER"
log_info "========================================="
log_info "Setup script preserved for other environments."
log_info "Your ${ENVIRONMENT} WordPress site is ready!"