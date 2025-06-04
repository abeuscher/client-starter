# WordPress Client Template

This repository serves as a starter template for creating new WordPress client sites with containerized development and deployment workflows.

## Quick Start for New Clients

### Step 1: Create Client Repository

1. **Fork this repository** to create a new client repository
   - Name it: `client-[clientname]` (e.g., `client-widgetsrus`)
   - Keep it private for client confidentiality

2. **Clone your forked repository** locally:
   ```bash
   git clone https://github.com/yourusername/client-[clientname]
   cd client-[clientname]
   ```

### Step 2: Customize Client Configuration

3. **Edit `package.json`** with client-specific details:
   ```json
   {
     "name": "client-widgetsrus",
     "description": "WordPress theme for Widgets R Us",
     "author": "Your Name <your.email@example.com>"
   }
   ```

4. **Configure environment files**:
   
   **Edit `.env.staging`**:
   ```bash
   ENVIRONMENT=staging
   
   # Database Configuration
   MYSQL_DATABASE=widgetsrus_staging
   MYSQL_USER=staging_user
   MYSQL_PASSWORD=secure_staging_password_123
   MYSQL_ROOT_PASSWORD=secure_staging_root_456
   MYSQL_HOST=widgetsrus-mysql-staging
   
   # WordPress Configuration
   WP_DOMAIN=staging.widgetsrus.com
   WP_TITLE=Widgets R Us (Staging)
   WP_ADMIN_USER=admin
   WP_ADMIN_PASSWORD=secure_staging_admin_789
   WP_ADMIN_EMAIL=admin@widgetsrus.com
   
   # Container Configuration
   CLIENT_NAME=widgetsrus
   CONTAINER_PREFIX=widgetsrus
   
   # Optional Settings
   WP_TIMEZONE=America/New_York
   REMOVE_DEFAULT_CONTENT=true
   ```
   
   **Edit `.env.production`**:
   ```bash
   ENVIRONMENT=production
   
   # Database Configuration (DIFFERENT PASSWORDS!)
   MYSQL_DATABASE=widgetsrus_prod
   MYSQL_USER=prod_user
   MYSQL_PASSWORD=ultra_secure_prod_password_abc
   MYSQL_ROOT_PASSWORD=ultra_secure_prod_root_def
   MYSQL_HOST=widgetsrus-mysql-prod
   
   # WordPress Configuration
   WP_DOMAIN=widgetsrus.com
   WP_TITLE=Widgets R Us
   WP_ADMIN_USER=admin
   WP_ADMIN_PASSWORD=ultra_secure_prod_admin_ghi
   WP_ADMIN_EMAIL=admin@widgetsrus.com
   
   # Container Configuration
   CLIENT_NAME=widgetsrus
   CONTAINER_PREFIX=widgetsrus
   
   # Optional Settings
   WP_TIMEZONE=America/New_York
   REMOVE_DEFAULT_CONTENT=true
   ```

5. **Commit your customizations**:
   ```bash
   git add .
   git commit -m "Initial client configuration for [Client Name]"
   git push origin main
   ```

### Step 3: Deploy to Server

6. **Deploy to staging server**:
   ```bash
   # On server, clone the repository
   git clone https://github.com/yourusername/client-[clientname]
   cd client-[clientname]
   
   # Set up staging environment
   cp .env.staging .env
   chmod +x setup.sh
   ./setup.sh
   ```

7. **Verify staging deployment**:
   - Visit `https://staging.[clientdomain].com`
   - Login to WordPress admin
   - Test theme functionality

### Step 4: Production Deployment (When Ready)

8. **Deploy to production**:
   ```bash
   # Set production environment
   cp .env.production .env
   ./setup.sh
   ```

9. **Promote content from staging to production**:
   - Export content from staging: WordPress Admin → Tools → Export
   - Import to production: WordPress Admin → Tools → Import
   - Sync media files if needed

## Development Workflow

### Local Development
```bash
# Install dependencies
npm install

# Start development with file watching
npm run watch

# Build for production
npm run production
```

### Theme Development
- Source files are in `src/` directory
- Templates: `src/templates/` (Pug files compiled to PHP)
- Styles: `src/styles/` (SCSS files compiled to CSS)
- Scripts: `src/scripts/` (JavaScript bundled with esbuild)
- Assets: `src/assets/` (copied to build directory)

### Deployment
- Push theme changes to repository
- Server pulls changes and rebuilds automatically
- Content promoted manually via XML export/import

## File Structure

```
├── README.md                 # This file
├── package.json             # Node.js dependencies and scripts
├── build.js                 # Build system (Pug→PHP, SCSS→CSS, JS bundling)
├── setup.sh                 # WordPress installation script
├── docker-compose.yml       # Container configuration
├── .env.staging             # Staging environment configuration
├── .env.production          # Production environment configuration
├── .env.template            # Template for environment variables
├── wp-config-template.php   # WordPress configuration template
├── src/                     # Theme source files
│   ├── templates/           # Pug templates (compiled to PHP)
│   ├── styles/              # SCSS stylesheets
│   ├── scripts/             # JavaScript files
│   └── assets/              # Images, fonts, etc.
└── public_html/             # WordPress installation (created by setup.sh)
```

## Environment Management

### Environment-Specific Setup
Each environment (local, staging, production) maintains:
- **Separate databases** with different credentials
- **Different domain names** for isolation
- **Independent WordPress installations**
- **Environment-specific container names**

### Safety Features
- Setup script prevents re-running on same environment
- Template files removed after setup for security
- Database credentials isolated per environment
- WordPress files never committed to repository

## Content Promotion Workflow

### Staging to Production
1. **Develop and test** content in staging environment
2. **Export content** from staging WordPress admin
3. **Import content** to production WordPress admin  
4. **Sync media files** using rsync or manual upload
5. **Test production** environment before going live

### Code vs Content
- **Code changes**: Deployed via git push → server pull → rebuild
- **Content changes**: Promoted via XML export/import + media sync
- **WordPress updates**: Applied via WP-CLI during maintenance windows

## Maintenance

### WordPress Updates
```bash
# Update WordPress core
wp core update --allow-root

# Update plugins
wp plugin update --all --allow-root

# Update themes (if using external themes)
wp theme update --all --allow-root
```

### Plugin Management
```bash
# Install new plugin
wp plugin install [plugin-name] --activate --allow-root

# Remove plugin
wp plugin deactivate [plugin-name] --allow-root
wp plugin delete [plugin-name] --allow-root
```

### Database Management
```bash
# Database backup
wp db export backup-$(date +%Y%m%d).sql --allow-root

# Database optimization
wp db optimize --allow-root
```

## Troubleshooting

### Setup Issues
- Check `.env` file has all required variables
- Verify database connection settings
- Ensure proper file permissions (755 for directories, 644 for files)
- Check Docker containers are running: `docker ps`

### Build Issues
- Clear build directory: `rm -rf public_html/wp-content/themes/[theme-name]`
- Rebuild: `npm run production`
- Check Node.js dependencies: `npm install`

### WordPress Issues
- Check wp-config.php was created correctly
- Verify database connection: `wp db check --allow-root`
- Reset WordPress if needed: Delete `public_html/` and re-run `./setup.sh`

## Support

For issues with this template system:
1. Check this README for common solutions
2. Review setup script logs for specific errors
3. Verify environment variables are correctly set
4. Ensure all required dependencies are installed

---

**Next Steps**: After setup is complete, begin theme development in the `src/` directory and test in your staging environment before promoting to production.