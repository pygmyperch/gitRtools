#' Reload R Package Development Workflow
#'
#' Streamlines the R package development cycle by automating documentation,
#' optional git commits, package reinstallation, and database disconnection.
#' Automatically detects package information from the current project.
#'
#' @param branch Character. Git branch to install from. Default is "main"
#' @param commit_message Character. Optional commit message. If provided, will commit changes
#' @param commit Logical. Whether to commit changes. Default is TRUE if commit_message provided
#' @param repo Character. GitHub repository in format "username/repo". Auto-detected if NULL
#' @param package Character. Package name. Auto-detected from DESCRIPTION if NULL
#' @param verbose Logical. Print detailed progress information. Default is TRUE
#'
#' @details
#' This function automates the common R package development workflow:
#' \enumerate{
#'   \item Documents the package using roxygen2
#'   \item Detects and safely disconnects database connections
#'   \item Optionally commits changes to git
#'   \item Safely uninstalls the current package version
#'   \item Reinstalls from GitHub
#'   \item Restarts the R session
#' }
#'
#' The function automatically detects:
#' \itemize{
#'   \item Package name from DESCRIPTION file
#'   \item GitHub repository from git remote configuration
#'   \item Current database connections in the global environment
#' }
#'
#' @examples
#' \dontrun{
#' # Basic reload from main branch
#' reload_package()
#'
#' # Reload with git commit
#' reload_package(commit_message = "Fix critical bug")
#'
#' # Reload from development branch
#' reload_package(branch = "development")
#'
#' # Reload without committing
#' reload_package(commit = FALSE)
#'
#' # Specify custom repo
#' reload_package(repo = "username/my-package", branch = "feature-branch")
#' }
#'
#' @importFrom devtools document install_github
#' @importFrom rstudioapi restartSession
#' @importFrom utils remove.packages
#' @export
reload_package <- function(branch = "main", 
                          commit_message = NULL, 
                          commit = !is.null(commit_message),
                          repo = NULL,
                          package = NULL,
                          verbose = TRUE) {
  
  if (verbose) cat("=== gitRtools: Reloading R Package ===\n")
  
  # Auto-detect package information
  pkg_info <- auto_detect_package_info(verbose = verbose)
  
  # Use provided values or fall back to auto-detected
  if (is.null(package)) package <- pkg_info$package
  if (is.null(repo)) repo <- pkg_info$repo
  
  if (is.null(package)) {
    stop("Could not detect package name. Please specify 'package' parameter or run from package directory.")
  }
  
  if (verbose) {
    cat("Package:", package, "\n")
    if (!is.null(repo)) cat("Repository:", repo, "\n")
    cat("Branch:", branch, "\n\n")
  }
  
  # Step 1: Document the package
  if (verbose) cat("Step 1: Documenting package...\n")
  tryCatch({
    devtools::document()
    if (verbose) cat("  ✓ Documentation updated\n")
  }, error = function(e) {
    if (verbose) cat("  ⚠ Documentation failed:", e$message, "\n")
  })
  
  # Step 2: Handle database connections
  if (verbose) cat("\nStep 2: Checking database connections...\n")
  detect_and_disconnect_dbs(verbose = verbose)
  
  # Step 3: Optional git commit
  if (commit && !is.null(commit_message)) {
    if (verbose) cat("\nStep 3: Committing changes...\n")
    dev_commit(commit_message, verbose = verbose)
  } else {
    if (verbose) cat("\nStep 3: Skipping git commit\n")
  }
  
  # Step 4: Uninstall current package
  if (verbose) cat("\nStep 4: Uninstalling current package...\n")
  safe_uninstall_package(package, verbose = verbose)
  
  # Step 5: Reinstall from GitHub
  if (!is.null(repo)) {
    if (verbose) cat("\nStep 5: Reinstalling from GitHub...\n")
    reinstall_from_github(repo, branch, verbose = verbose)
  } else {
    if (verbose) cat("\nStep 5: Skipping GitHub install (no repo detected)\n")
  }
  
  # Step 6: Restart R session
  if (verbose) {
    cat("\n=== Workflow Complete ===\n")
    cat("Restarting R session...\n")
    cat("After restart, reload library with: library(", package, ")\n", sep = "")
  }
  
  # Small delay to ensure user sees the message
  Sys.sleep(1)
  
  # Restart the session
  rstudioapi::restartSession()
}

#' Auto-detect package information from current project
#' @keywords internal
auto_detect_package_info <- function(verbose = FALSE) {
  
  # Try to read DESCRIPTION file
  desc_file <- "DESCRIPTION"
  package <- NULL
  
  if (file.exists(desc_file)) {
    tryCatch({
      desc_content <- readLines(desc_file)
      package_line <- grep("^Package:", desc_content, value = TRUE)
      if (length(package_line) > 0) {
        package <- trimws(sub("^Package:", "", package_line[1]))
      }
    }, error = function(e) {
      if (verbose) cat("  ⚠ Could not read DESCRIPTION file\n")
    })
  }
  
  # Try to detect GitHub repo from git remote
  repo <- NULL
  tryCatch({
    git_remote <- system("git remote get-url origin", intern = TRUE, ignore.stderr = TRUE)
    if (length(git_remote) > 0 && !attr(git_remote, "status", exact = TRUE)) {
      # Parse GitHub URL
      if (grepl("github.com", git_remote)) {
        # Handle both SSH and HTTPS URLs
        if (grepl("^git@github.com:", git_remote)) {
          # SSH format: git@github.com:username/repo.git
          repo <- sub("^git@github.com:", "", git_remote)
          repo <- sub("\\.git$", "", repo)
        } else if (grepl("^https://github.com/", git_remote)) {
          # HTTPS format: https://github.com/username/repo.git
          repo <- sub("^https://github.com/", "", git_remote)
          repo <- sub("\\.git$", "", repo)
        }
      }
    }
  }, error = function(e) {
    if (verbose) cat("  ⚠ Could not detect git remote\n")
  })
  
  return(list(package = package, repo = repo))
}

#' Safely uninstall package
#' @keywords internal
safe_uninstall_package <- function(package, verbose = FALSE) {
  
  # First try to detach if loaded
  package_env <- paste0("package:", package)
  if (package_env %in% search()) {
    tryCatch({
      detach(package_env, unload = TRUE, character.only = TRUE)
      if (verbose) cat("  ✓ Package detached\n")
    }, error = function(e) {
      if (verbose) cat("  ⚠ Could not detach package:", e$message, "\n")
    })
  }
  
  # Try to remove package
  if (package %in% rownames(installed.packages())) {
    tryCatch({
      remove.packages(package)
      if (verbose) cat("  ✓ Package removed\n")
    }, error = function(e) {
      if (verbose) cat("  ⚠ Could not remove package:", e$message, "\n")
    })
  } else {
    if (verbose) cat("  ⚠ Package not currently installed\n")
  }
}

#' Reinstall package from GitHub
#' @keywords internal
reinstall_from_github <- function(repo, branch, verbose = FALSE) {
  
  repo_with_branch <- if (branch != "main") paste0(repo, "@", branch) else repo
  
  tryCatch({
    devtools::install_github(repo_with_branch, upgrade = "never")
    if (verbose) cat("  ✓ Package reinstalled from", repo_with_branch, "\n")
  }, error = function(e) {
    if (verbose) cat("  ⚠ Installation failed:", e$message, "\n")
  })
}