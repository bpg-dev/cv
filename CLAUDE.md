# CLAUDE.md

Personal CV/resume website built with Hugo static site generator.

## Quick Commands

```bash
hugo server        # Start Hugo dev server (localhost:1313)
make hugo          # Build site to public/
make run           # Build and run in Docker (localhost:8080)
make docker-build  # Build Docker image only
make docker-run    # Run Docker container only
make clean         # Remove public/ and resources/_gen/
```

## Common Tasks

- **Update resume content** → `data/data.yaml`
- **Change styles** → `assets/css/main.scss`
- **Modify section template** → `layouts/partials/<section>.html`
- **Update profile photo** → Replace `assets/images/profile.jpg`
- **Add external script** → Update CSP in `static-web-server.toml`
- **Change site metadata** → `config.yaml`

## Project Structure

```text
config.yaml              # Hugo configuration
static-web-server.toml   # Web server config (security headers, caching)
data/data.yaml           # Resume content (experience, skills, education, etc.)
content/_index.md        # Main page markdown
layouts/
  index.html             # Main template
  partials/              # Reusable components (experience.html, skills.html, etc.)
assets/
  css/main.scss          # Styles
  icons/                 # SVG icons
  images/                # Profile photo, etc.
static/                  # Favicon, fonts, robots.txt
```

## Key Files

- **data/data.yaml** - All resume data: contact info, experience, skills, education, projects, certificates, awards
- **config.yaml** - Site title, base URL, analytics (Umami), build settings
- **static-web-server.toml** - Security headers (CSP, HSTS), caching rules
- **layouts/partials/** - Each resume section has its own partial template

## Tech Stack

- **Hugo** (Extended) - Static site generator with SCSS
- **Docker** - Multi-stage build with distroless base image
- **static-web-server** - Lightweight Rust-based web server (~5MB)
- **GitHub Actions** - CI/CD to GitHub Container Registry

## Data Structure (data/data.yaml)

```yaml
basic:        # name, title, avatar
contact:      # location, email, website, linkedin, github, etc.
profile:      # show, order, title, description
experience:   # show, order, title, items: [{company, link, date, role, location, description}]
project:      # show, order, title, items: [{name, link, date, description}]
skill:        # show, order, title, groups: [{name, item: []}]
education:    # show, order, title, items: [{institution, date, major, degree}]
certificate:  # show, order, title, items: [{name, issuer, date, link}]
language:     # show, order, title, items: [{idiom, level}]
interest:     # show, order, title, items: [{item, link}]
```

Each section has `show: true/false` and `order: N` to control visibility and display order.

## Template Syntax

Hugo uses Go templates. Common patterns in this project:

```go
{{ .Site.Data.data.basic.name }}     // Access data.yaml values
{{ range .items }}...{{ end }}       // Loop over arrays
{{ with .link }}<a href="{{ . }}">{{ end }}  // Conditional wrapper
{{ .description | markdownify }}     // Render markdown in YAML
```

## Verify Changes

Run `hugo server` and check <http://localhost:1313> before committing.

## Deployment

CI/CD automatically builds and pushes Docker images on push to `main`.

Infrastructure/Kubernetes config is in separate repo: `../home-ops/kubernetes/apps/default/cv-site`
