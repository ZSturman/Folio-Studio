# Folio

A macOS document-based application for creating and managing portfolio project files. Folio provides a structured, single-source-of-truth format for documenting creative and professional work, making it easy to maintain and export portfolio content.

## Overview

Folio is a SwiftUI-based macOS app that helps you organize portfolio projects through a custom `.folio` document format. Each document captures comprehensive project information including metadata, media assets, classifications, and collections—all in a portable JSON-based file format.

## Features

### Document-Based Architecture

- **Custom File Format**: `.folio` files (JSON-based) that encapsulate all project data
- **Launcher Window**: Quick access to recent documents and project creation
- **Multi-Document Support**: Open and work on multiple portfolio projects simultaneously

### Comprehensive Project Data Model

#### Basic Information

- Title, subtitle, and summary
- Domain and category classification
- Project status and phase tracking
- Featured/public visibility flags
- Creation and update timestamps

#### Media Management

- Image asset management with dedicated assets folder
- Built-in image editor with cropping and transformation tools
- Support for multiple image slots (cover, thumbnail, banner, etc.)
- Labeled image previews and cover rendering

#### Classification System

- **Tags**: Flexible tagging system
- **Mediums**: Project medium classification (e.g., digital, physical)
- **Genres**: Genre categorization
- **Topics**: Thematic topics
- **Subjects**: Subject matter classification

#### Content

- Rich text story and description fields
- Resource management with categorized links and references
- Extensible resource catalog with types and categories

#### Collections

- Organize related items within projects
- Support for multiple collection types
- Collection item management with metadata

#### Custom Data

- Key-value pairs for additional project details
- Flexible JSON value storage for custom attributes

### User Interface

Organized into tab-based sections:

- **Basic Info**: Core project metadata and settings
- **Classification**: Tags, mediums, genres, topics, and subjects
- **Content**: Project story, description, and resources
- **Media**: Image management and editing
- **Collection**: Organized collections of related items
- **Other**: Custom key-value data
- **Settings**: Application preferences

### Data Persistence

- **SwiftData**: Local database for taxonomy management (tags, mediums, genres, etc.)
- **Document Storage**: JSON-serialized `.folio` files
- **Migration Support**: Schema versioning and migration plan
- **Seeding**: Automatic initialization of default taxonomies and resource categories

## Requirements

- macOS (SwiftUI-based)
- Xcode 15+ (for development)

## Project Structure

```text
Folio/
├── Document/              # Document model and JSON handling
├── Models/                # SwiftData models for taxonomy
├── Setup/                 # Migration plans and bootstrapping
├── UI/
│   ├── Tabs/             # Main content tabs
│   ├── Media/            # Image editing and management
│   ├── Collection/       # Collection management
│   ├── PickersAndToggles/ # UI controls
│   ├── Resources/        # Resource management views
│   └── TextAndListsEditors/ # Text and taxonomy editors
└── Assets.xcassets/      # App assets
```

## Document Format

Folio documents are JSON files with a `.folio` extension. Here's an example of a complete document structure:

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "filePath": "/Users/username/Documents/my-project.folio",
  
  "title": "My Portfolio Project",
  "subtitle": "A Creative Web Application",
  "summary": "An interactive web experience showcasing modern design principles",
  "isPublic": true,
  "featured": true,
  "requiresFollowUp": false,
  
  "domain": "technology",
  "category": "web-development",
  "status": "completed",
  "phase": "live",
  
  "createdAt": "2025-01-15T10:00:00Z",
  "updatedAt": "2025-11-08T14:30:00Z",
  
  "tags": ["web", "interactive", "design"],
  "mediums": ["digital"],
  "genres": ["experimental"],
  "topics": ["user-experience", "animation"],
  "subjects": ["web-design", "javascript"],
  
  "description": "Detailed technical description of the project...",
  "story": "The inspiration and journey behind this project...",
  
  "images": {
    "thumbnail": {
      "original": "assets/thumbnail-original.jpg",
      "edited": "assets/thumbnail-edited.jpg"
    },
    "banner": {
      "original": "assets/banner-original.jpg",
      "edited": "assets/banner-edited.jpg"
    }
  },
  "assetsFolder": "assets",
  
  "resources": [
    {
      "label": "Live Site",
      "category": "deployment",
      "type": "website",
      "url": "https://example.com"
    },
    {
      "label": "GitHub Repository",
      "category": "code",
      "type": "repository",
      "url": "https://github.com/username/project"
    }
  ],
  
  "collection": {
    "screenshots": [
      {
        "id": "456e7890-e89b-12d3-a456-426614174001",
        "type": "image",
        "label": "Home Page",
        "summary": "Landing page with hero animation",
        "thumbnail": {
          "original": "assets/collections/screenshot1-thumb.jpg"
        },
        "filePath": {
          "original": "assets/collections/screenshot1.jpg"
        },
        "resource": {
          "label": "",
          "category": "",
          "type": "",
          "url": ""
        }
      }
    ]
  },
  
  "details": [
    {
      "key": "client",
      "value": "ACME Corporation"
    },
    {
      "key": "duration",
      "value": "3 months"
    }
  ],
  
  "values": {
    "custom_field": "custom_value",
    "metadata": {
      "nested": "data"
    }
  }
}
```

### Key Format Features

- **UUID-based IDs**: Each document and collection item has a unique identifier
- **Relative Asset Paths**: Images and media reference files relative to the document location
- **Flexible Taxonomy**: Tags, mediums, genres, topics, and subjects are simple string arrays
- **Typed Resources**: Resources are categorized with labels, types, and URLs
- **Nested Collections**: Collections organize related items with their own metadata
- **Extensible Values**: Custom key-value pairs and arbitrary JSON structures supported

## Using Folio Documents

### Parsing and Integration

Since `.folio` files are standard JSON, they can be easily parsed and integrated into various systems:

#### JavaScript/TypeScript

```javascript
// Node.js or Browser
const fs = require('fs');
const project = JSON.parse(fs.readFileSync('my-project.folio', 'utf8'));

console.log(project.title); // "My Portfolio Project"
console.log(project.tags);  // ["web", "interactive", "design"]
```

#### Python

```python
import json

with open('my-project.folio', 'r') as f:
    project = json.load(f)
    
print(project['title'])
print(project['resources'])
```

#### Static Site Generators

Next.js / React:

```typescript
import projectData from './projects/my-project.folio';

export default function ProjectPage() {
  return (
    <div>
      <h1>{projectData.title}</h1>
      <p>{projectData.summary}</p>
      <img src={projectData.images.thumbnail.edited} />
    </div>
  );
}
```

Astro:

```astro
---
import { readFileSync } from 'fs';
const project = JSON.parse(readFileSync('./my-project.folio', 'utf8'));
---

<article>
  <h1>{project.title}</h1>
  <p>{project.story}</p>
  <ul>
    {project.tags.map(tag => <li>{tag}</li>)}
  </ul>
</article>
```

### Common Use Cases

#### Portfolio Website Generation

Use Folio documents as a content source for your portfolio website. Parse multiple `.folio` files to automatically generate:

- Project listing pages with filtering by tags, domain, or status
- Individual project detail pages
- Media galleries from collection items
- Categorized resource links

#### Content Management

- Store all project documents in a Git repository for version control
- Share `.folio` files with collaborators
- Export subsets of projects based on `isPublic` or `featured` flags
- Generate different views for different audiences

#### Data Aggregation

```javascript
// Aggregate all projects
const projects = fs.readdirSync('./projects')
  .filter(f => f.endsWith('.folio'))
  .map(f => JSON.parse(fs.readFileSync(`./projects/${f}`, 'utf8')));

// Filter by criteria
const featuredProjects = projects.filter(p => p.featured);
const techProjects = projects.filter(p => p.domain === 'technology');
const publicProjects = projects.filter(p => p.isPublic);

// Generate taxonomy indexes
const allTags = [...new Set(projects.flatMap(p => p.tags))];
const projectsByTag = allTags.reduce((acc, tag) => {
  acc[tag] = projects.filter(p => p.tags.includes(tag));
  return acc;
}, {});
```

#### API Integration

```javascript
// Express.js API endpoint
app.get('/api/projects', (req, res) => {
  const projects = loadAllFolioFiles('./projects');
  res.json(projects.filter(p => p.isPublic));
});

app.get('/api/projects/:id', (req, res) => {
  const project = loadFolioFile(`./projects/${req.params.id}.folio`);
  res.json(project);
});
```

## Technical Details

- **Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Document Type**: Custom UTI (`com.zachary-sturman.folio`)
- **File Format**: JSON with `.folio` extension
- **Architecture**: Document-based app with model-view coordinator pattern

## Development

Built with Swift and SwiftUI, leveraging:

- SwiftData for local taxonomy management
- FileDocument protocol for custom document types
- UniformTypeIdentifiers for file type registration
- NavigationSplitView for organized UI layout

## License

Created by Zachary Sturman
