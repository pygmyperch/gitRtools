#' Commit Changes to Git Repository
#'
#' Commits all staged and unstaged changes to the current git repository with
#' a specified commit message. Optionally pushes changes to the remote repository.
#'
#' @param message Character. Commit message (required)
#' @param push Logical. Whether to push changes to remote after committing. Default is FALSE
#' @param add_all Logical. Whether to stage all changes before committing. Default is TRUE
#' @param verbose Logical. Print detailed git operations. Default is TRUE
#'
#' @return Logical. TRUE if commit was successful, FALSE otherwise
#'
#' @details
#' This function performs git operations in the following order:
#' \enumerate{
#'   \item Optionally stage all changes (git add .)
#'   \item Commit with the provided message
#'   \item Optionally push to remote repository
#' }
#'
#' The function checks for git repository existence and provides informative
#' error messages if operations fail.
#'
#' @examples
#' \dontrun{
#' # Simple commit
#' dev_commit("Fix critical bug")
#'
#' # Commit and push to remote
#' dev_commit("Add new feature", push = TRUE)
#'
#' # Commit only staged changes
#' dev_commit("Update documentation", add_all = FALSE)
#'
#' # Silent operation
#' dev_commit("Minor fix", verbose = FALSE)
#' }
#'
#' @export
dev_commit <- function(message, push = FALSE, add_all = TRUE, verbose = TRUE) {
  
  if (missing(message) || is.null(message) || nchar(trimws(message)) == 0) {
    stop("Commit message is required")
  }
  
  if (verbose) cat("Git operations:\n")
  
  # Check if we're in a git repository
  if (!dir.exists(".git")) {
    if (verbose) cat("  ⚠ Not in a git repository\n")
    return(FALSE)
  }
  
  # Stage changes if requested
  if (add_all) {
    if (verbose) cat("  Staging all changes...\n")
    result <- system("git add .", ignore.stderr = !verbose)
    if (result != 0) {
      if (verbose) cat("  ⚠ Failed to stage changes\n")
      return(FALSE)
    }
    if (verbose) cat("    ✓ Changes staged\n")
  }
  
  # Check if there are changes to commit
  status_result <- system("git diff --cached --quiet", ignore.stderr = TRUE)
  if (status_result == 0) {
    if (verbose) cat("  ⚠ No staged changes to commit\n")
    return(FALSE)
  }
  
  # Commit changes
  if (verbose) cat("  Committing changes...\n")
  commit_cmd <- paste0("git commit -m \"", message, "\"")
  result <- system(commit_cmd, ignore.stderr = !verbose)
  
  if (result != 0) {
    if (verbose) cat("  ⚠ Commit failed\n")
    return(FALSE)
  }
  
  if (verbose) cat("    ✓ Committed:", message, "\n")
  
  # Push if requested
  if (push) {
    if (verbose) cat("  Pushing to remote...\n")
    
    # Check if remote exists
    remote_check <- system("git remote", ignore.stderr = TRUE, intern = TRUE)
    if (length(remote_check) == 0) {
      if (verbose) cat("  ⚠ No remote repository configured\n")
      return(TRUE)  # Commit was successful, just no remote
    }
    
    # Push to remote
    push_result <- system("git push", ignore.stderr = !verbose)
    if (push_result != 0) {
      if (verbose) cat("  ⚠ Push failed\n")
      return(TRUE)  # Commit was successful, push failed
    }
    
    if (verbose) cat("    ✓ Pushed to remote\n")
  }
  
  return(TRUE)
}

#' Get Git Repository Status
#'
#' Returns information about the current git repository status including
#' branch name, staged changes, and remote information.
#'
#' @param verbose Logical. Print status information to console. Default is TRUE
#'
#' @return List containing repository status information
#'
#' @details
#' Returns a list with the following elements:
#' \itemize{
#'   \item branch: Current branch name
#'   \item has_changes: Whether there are uncommitted changes
#'   \item has_staged: Whether there are staged changes
#'   \item remote_url: URL of the remote repository
#'   \item ahead_behind: Commits ahead/behind remote (if available)
#' }
#'
#' @examples
#' \dontrun{
#' # Get status information
#' status <- get_git_status()
#'
#' # Silent operation
#' status <- get_git_status(verbose = FALSE)
#'
#' # Check if there are uncommitted changes
#' if (status$has_changes) {
#'   cat("You have uncommitted changes\n")
#' }
#' }
#'
#' @export
get_git_status <- function(verbose = TRUE) {
  
  # Initialize status list
  status <- list(
    branch = NULL,
    has_changes = FALSE,
    has_staged = FALSE,
    remote_url = NULL,
    ahead_behind = NULL
  )
  
  # Check if we're in a git repository
  if (!dir.exists(".git")) {
    if (verbose) cat("Not in a git repository\n")
    return(status)
  }
  
  # Get current branch
  tryCatch({
    branch <- system("git branch --show-current", intern = TRUE, ignore.stderr = TRUE)
    if (length(branch) > 0) {
      status$branch <- branch[1]
    }
  }, error = function(e) {
    # Ignore errors
  })
  
  # Check for uncommitted changes
  tryCatch({
    # Check working directory changes
    changes_result <- system("git diff --quiet", ignore.stderr = TRUE)
    status$has_changes <- (changes_result != 0)
    
    # Check staged changes
    staged_result <- system("git diff --cached --quiet", ignore.stderr = TRUE)
    status$has_staged <- (staged_result != 0)
  }, error = function(e) {
    # Ignore errors
  })
  
  # Get remote URL
  tryCatch({
    remote <- system("git remote get-url origin", intern = TRUE, ignore.stderr = TRUE)
    if (length(remote) > 0) {
      status$remote_url <- remote[1]
    }
  }, error = function(e) {
    # Ignore errors
  })
  
  # Print status if verbose
  if (verbose) {
    cat("Git Repository Status:\n")
    if (!is.null(status$branch)) {
      cat("  Branch:", status$branch, "\n")
    }
    if (status$has_changes) {
      cat("  ⚠ Uncommitted changes detected\n")
    }
    if (status$has_staged) {
      cat("  ✓ Staged changes ready for commit\n")
    }
    if (!is.null(status$remote_url)) {
      cat("  Remote:", status$remote_url, "\n")
    }
    if (!status$has_changes && !status$has_staged) {
      cat("  ✓ Working directory clean\n")
    }
  }
  
  return(status)
}