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
   The built site will be in the `public/` directory.

## Project Structure

```
.
├── config.yaml          # Hugo configuration
├── content/              # Content files (markdown)
│   └── _index.md        # Homepage
├── data/                # Data files (YAML/JSON)
│   └── data.yaml       # Resume data
├── layouts/             # HTML templates
│   ├── index.html      # Main layout
│   └── partials/       # Reusable components
│       ├── basic.html
│       ├── contact.html
│       ├── experience.html
│       └── ...
├── assets/              # Static assets
│   ├── css/            # Stylesheets (SCSS)
│   ├── images/         # Images
│   └── ...
└── public/              # Generated site (gitignored)
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

The site is automatically built and deployed to GitHub Pages via GitHub Actions when you push to the `main` branch.

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

