# Online Resume / CV

A Hugo-based static site for hosting an online resume/CV. This project was migrated from Jekyll to Hugo for easier maintenance and faster builds.

## Prerequisites

- [Hugo](https://gohugo.io/installation/) (Extended version recommended for SCSS support)
- Git

## Quick Start

### Install Hugo

**macOS (Homebrew):**

```bash
brew install hugo
```

**Linux:**

```bash
# Download from https://github.com/gohugoio/hugo/releases
# Or use your package manager
```

**Windows:**
Download from [Hugo releases](https://github.com/gohugoio/hugo/releases)

### Development Server

1. **Start the development server:**

   ```bash
   hugo server
   ```

2. **View your site:**
   - Open `http://localhost:1313` in your browser
   - Changes will automatically reload

3. **Build the site:**

   ```bash
   hugo
   ```

   Or use the Makefile:

   ```bash
   make hugo
   ```

   The built site will be in the `public/` directory.

### Using Makefile

The project includes a Makefile for common tasks:

**Build Hugo site locally:**

```bash
make hugo
```

**Build and run in Docker:**

```bash
make run
```

This will build the Docker image and run it on port 8080 (configurable via `PORT` variable).

**Other available commands:**

- `make docker-build` - Build Docker image only
- `make docker-run` - Run Docker container only
- `make clean` - Remove build artifacts (`public/`, `resources/_gen/`)
- `make docker-clean` - Stop and remove Docker container
- `make help` - Show all available commands

**Customizing Docker commands:**

```bash
# Use custom image name and tag
make docker-build IMAGE_NAME=my-cv IMAGE_TAG=v1.0

# Run on different port
make docker-run PORT=3000

# Use custom container name
make docker-run CONTAINER_NAME=my-cv-container
```

## Project Structure

```text
.
├── config.yaml          # Hugo configuration
├── static-web-server.toml  # Web server configuration
├── Dockerfile          # Multi-stage Docker build
├── Makefile            # Build automation commands
├── content/            # Content files (markdown)
│   └── _index.md      # Homepage
├── data/               # Data files (YAML/JSON)
│   └── data.yaml      # Resume data
├── layouts/            # HTML templates
│   ├── index.html     # Main layout
│   └── partials/      # Reusable components
│       ├── basic.html
│       ├── contact.html
│       ├── experience.html
│       └── ...
├── assets/             # Static assets
│   ├── css/           # Stylesheets (SCSS)
│   ├── images/        # Images
│   └── ...
├── static/             # Static files (copied as-is)
│   └── assets/        # Static assets (fonts, icons, etc.)
└── public/             # Generated site (gitignored)
```

## Editing Your Resume

Edit `data/data.yaml` to update your resume content:

- Personal information (name, contact, profile)
- Work experience
- Skills
- Education
- Projects
- Certificates

Changes will be automatically reflected when the development server is running.

## Configuration

Edit `config.yaml` to customize:

- Site title and metadata
- Theme colors and styling
- Analytics settings
- Open Graph settings

## Deployment

### Docker/Kubernetes Deployment

The site is containerized using Docker and can be deployed to Kubernetes.

#### Automated Build

A GitHub Actions workflow (`.github/workflows/docker-build.yml`) automatically:

- Builds the Hugo site
- Creates a multi-stage Docker image with static-web-server
- Pushes the image to GitHub Container Registry (GHCR)
- Tags images with `YYYYMMDD-<commit-sha>` and `latest`

**Image location:** `ghcr.io/<your-username>/<repository-name>`

**Triggers:**

- Push to `main` branch
- Manual workflow dispatch

#### Building Locally

**Using Makefile (recommended):**

```bash
# Build and run in one command
make run
```

The site will be available at `http://localhost:8080` (or custom port via `PORT` variable).

**Using Docker directly:**

1. **Build the Docker image:**

   ```bash
   docker build -t cv-site:latest .
   ```

   Or use Makefile:

   ```bash
   make docker-build
   ```

2. **Run the container:**

   ```bash
   docker run -p 8080:8080 cv-site:latest
   ```

   Or use Makefile:

   ```bash
   make docker-run
   ```

3. **Pull from GHCR:**

   ```bash
   docker pull ghcr.io/<your-username>/<repository-name>:latest
   ```

#### Kubernetes Deployment

Use the Docker image in your Kubernetes manifests. The image:

- Serves static files via static-web-server on port 8080 (HTTP)
- Includes health check endpoint at `/health`
- Runs as non-root user (distroless base)

**Example Kubernetes Service:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cv-site
spec:
  selector:
    app: cv-site
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
```

### GitHub Pages (Legacy)

The site can also be deployed to GitHub Pages via `.github/workflows/hugo.yml` when you push to the `main` branch.

### Manual Deployment

1. Build the site:

   ```bash
   hugo
   ```

2. Deploy the `public/` directory to your hosting service.

## Migration from Jekyll

This site was migrated from Jekyll. Key differences:

- **Data files**: `_data/data.yml` → `data/data.yaml` (same format)
- **Templates**: `_includes/` → `layouts/partials/` (Liquid → Go templates)
- **Layouts**: `_layouts/` → `layouts/` (Liquid → Go templates)
- **Config**: `_config.yml` → `config.yaml` (YAML format similar)
- **Assets**: `assets/` remains the same (Hugo has built-in SCSS support)

## Troubleshooting

**Hugo not found:**

- Ensure Hugo is installed and in your PATH
- Use `hugo version` to verify installation

**SCSS not compiling:**

- Install the Extended version of Hugo (includes SCSS support)
- Check that `assets/css/main.scss` has the front matter (`---`)

**Changes not reflecting:**

- Restart the Hugo server
- Clear the cache: `hugo --cleanDestinationDir`

## Resources

- [Hugo Documentation](https://gohugo.io/documentation/)
- [Hugo Quick Start](https://gohugo.io/getting-started/quick-start/)
- [Go Template Primer](https://gohugo.io/templates/introduction/)
- [static-web-server Documentation](https://static-web-server.net/)
