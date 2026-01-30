# CLAUDE.md

Personal CV/resume website built with Hugo static site generator.

## Quick Commands

```bash
make run           # Start Hugo dev server (localhost:1313)
make build         # Build site to public/
make docker-build  # Build Docker image
make docker-run    # Run container locally (port 8080)
make clean         # Remove public/ directory
```

## Project Structure

```text
config.yaml          # Hugo configuration
data/data.yaml       # Resume content (experience, skills, education, etc.)
content/_index.md    # Main page markdown
layouts/
  index.html         # Main template
  partials/          # Reusable components (experience.html, skills.html, etc.)
assets/
  css/main.scss      # Styles
  icons/             # SVG icons
  images/            # Profile photo, etc.
static/              # Favicon, fonts, robots.txt
```

## Key Files

- **data/data.yaml** - All resume data: contact info, experience, skills, education, projects, certificates, awards
- **config.yaml** - Site title, base URL, analytics (Umami), build settings
- **layouts/partials/** - Each resume section has its own partial template

## Tech Stack

- **Hugo** (Extended) - Static site generator with SCSS
- **Docker** - Multi-stage build (Hugo builder + Caddy runtime)
- **Caddy** - Web server with compression and security headers
- **GitHub Actions** - CI/CD to GitHub Container Registry

## Deployment

CI/CD automatically builds and pushes Docker images on push to `main`.

Infrastructure/Kubernetes config is in separate repo: `../home-ops/kubernetes/apps/default/cv-site`
