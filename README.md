# gitRtools

**Git and R Development Workflow Tools**

Streamlined workflow tools for R package development with Git integration. Automates documentation, package reinstallation, and database connection management during development cycles.

## Installation

Install from GitHub:

```r
# Install devtools if you haven't already
install.packages("devtools")

# Install gitRtools
devtools::install_github("pygmyperch/gitRtools")
```

## Quick Start

The main function `reload_package()` automates your entire development workflow:

```r
library(gitRtools)

# Basic usage (from your package directory)
reload_package()

# With git commit
reload_package(commit_message = "Fix critical bug")

# From a specific branch
reload_package(branch = "development")
```

## Core Functions

### `reload_package()`

The main workflow function that:
1. ✅ Documents your package with `roxygen2`
2. 🔌 Detects and disconnects database connections
3. 📝 Optionally commits changes to git
4. 🗑️ Safely uninstalls current package version
5. 📦 Reinstalls from GitHub
6. 🔄 Restarts R session

**Parameters:**
- `branch` - Git branch to install from (default: "main")
- `commit_message` - Optional commit message (triggers git commit)
- `commit` - Whether to commit (default: TRUE if commit_message provided)
- `repo` - GitHub repo "username/package" (auto-detected)
- `package` - Package name (auto-detected from DESCRIPTION)
- `verbose` - Show detailed progress (default: TRUE)

### `detect_and_disconnect_dbs()`

Intelligently finds and manages database connections:
- Scans global environment for DB connections
- Reports connection details to console
- Safely disconnects all found connections
- Supports DBI, SQLite, PostgreSQL, MySQL, and more

```r
# Just detect and report
detect_and_disconnect_dbs(disconnect = FALSE)

# Detect and disconnect all
detect_and_disconnect_dbs()
```

### `dev_commit()`

Simplified git operations:

```r
# Simple commit
dev_commit("Fix critical bug")

# Commit and push
dev_commit("Add new feature", push = TRUE)

# Commit only staged files
dev_commit("Update docs", add_all = FALSE)
```

## Auto-Detection Features

gitRtools automatically detects:

- 📦 **Package name** from DESCRIPTION file
- 🔗 **GitHub repository** from git remote configuration  
- 🔌 **Database connections** in global environment
- 🌿 **Current branch** from git status

## Setup for Auto-Loading

Add to your `~/.Rprofile` for automatic loading:

```r
# Auto-load gitRtools in package development projects
if (file.exists("DESCRIPTION") && file.exists("R/")) {
  suppressMessages(library(gitRtools))
  cat("gitRtools loaded for package development\n")
}
```

## Example Workflows

### Standard Development Cycle

```r
# Make your code changes...

# Document, commit, and reload
reload_package(commit_message = "Implement new feature")

# R session restarts automatically
# After restart:
library(your_package)  # Manual step
```

### Working with Branches

```r
# Develop on feature branch
reload_package(branch = "feature-xyz", commit_message = "WIP: new feature")

# Switch to main branch
reload_package(branch = "main")
```

### Database-Heavy Projects

gitRtools automatically handles common database connections:

```r
# Your typical setup
con <- DBI::dbConnect(RSQLite::SQLite(), "my_database.db")
db <- connect_to_postgres(...)

# gitRtools will detect and report:
reload_package()
# > Scanning for database connections...
# >   Found: con (SQLiteConnection) - active
# >   Found: db (PqConnection) - active
# >     ✓ Disconnected: con
# >     ✓ Disconnected: db
```

## Supported Database Types

- SQLite (RSQLite)
- PostgreSQL (RPostgreSQL, RPostgres)
- MySQL/MariaDB (RMySQL, RMariaDB)
- ODBC connections
- Any DBI-compliant connection
- Custom connections (by variable name matching)

## Benefits

- ⚡ **Fast**: One command replaces 8+ manual steps
- 🧠 **Smart**: Auto-detects package info and connections
- 🛡️ **Safe**: Graceful error handling and validation
- 🔄 **Universal**: Works with any R package project
- 📊 **Informative**: Detailed progress reporting
- 🎯 **Focused**: Handles tedious tasks so you can focus on coding

## Requirements

- R >= 3.5.0
- devtools package
- rstudioapi package (for session restart)
- DBI package (for database detection)
- Git repository with GitHub remote (for reinstallation)

## License

MIT License

## Contributing

Issues and pull requests welcome! Please report any bugs or feature requests on GitHub.
