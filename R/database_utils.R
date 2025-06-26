#' Detect and Disconnect Database Connections
#'
#' Scans the global environment for database connections and safely disconnects them.
#' Reports all detected connections to the console for user awareness.
#'
#' @param verbose Logical. Print detailed information about detected connections. Default is TRUE
#' @param disconnect Logical. Whether to actually disconnect found connections. Default is TRUE
#'
#' @return Invisibly returns a list of information about detected connections
#'
#' @details
#' This function searches the global environment for objects that appear to be
#' database connections, including:
#' \itemize{
#'   \item DBI connections (SQLite, PostgreSQL, MySQL, etc.)
#'   \item Objects with common connection names (con, db, conn, database)
#'   \item Any object that responds to DBI::dbIsValid()
#' }
#'
#' For each detected connection, it will:
#' \itemize{
#'   \item Report the variable name and connection type
#'   \item Check if the connection is still valid
#'   \item Safely disconnect if requested
#'   \item Provide summary information
#' }
#'
#' @examples
#' \dontrun{
#' # Just detect and report (no disconnection)
#' detect_and_disconnect_dbs(disconnect = FALSE)
#'
#' # Detect and disconnect all found connections
#' detect_and_disconnect_dbs()
#'
#' # Silent operation
#' detect_and_disconnect_dbs(verbose = FALSE)
#' }
#'
#' @importFrom DBI dbIsValid dbDisconnect
#' @export
detect_and_disconnect_dbs <- function(verbose = TRUE, disconnect = TRUE) {
  
  if (verbose) cat("Scanning for database connections...\n")
  
  # Get all objects in global environment
  env_objects <- ls(envir = .GlobalEnv)
  
  # Common database connection variable names
  common_db_names <- c("con", "conn", "db", "database", "connection")
  
  # Track detected connections
  detected_connections <- list()
  
  # Check each object in global environment
  for (obj_name in env_objects) {
    obj <- get(obj_name, envir = .GlobalEnv)
    
    # Skip if NULL
    if (is.null(obj)) next
    
    # Check if it's a database connection
    is_db_connection <- FALSE
    connection_type <- "Unknown"
    is_valid <- FALSE
    
    # Method 1: Check if it inherits from DBI connection classes
    if (inherits(obj, c("DBIConnection", "SQLiteConnection", "PqConnection", 
                       "MySQLConnection", "MariaDBConnection", "OdbcConnection"))) {
      is_db_connection <- TRUE
      connection_type <- class(obj)[1]
    }
    
    # Method 2: Check if it responds to DBI functions
    if (!is_db_connection) {
      tryCatch({
        if (DBI::dbIsValid(obj)) {
          is_db_connection <- TRUE
          connection_type <- paste(class(obj), collapse = ", ")
        }
      }, error = function(e) {
        # Not a DBI connection, continue
      })
    }
    
    # Method 3: Check common variable names with basic validation
    if (!is_db_connection && obj_name %in% common_db_names) {
      tryCatch({
        # Try to call dbIsValid - if it doesn't error, it's likely a DB connection
        valid_result <- DBI::dbIsValid(obj)
        is_db_connection <- TRUE
        connection_type <- paste(class(obj), collapse = ", ")
        is_valid <- valid_result
      }, error = function(e) {
        # Not a DBI connection
      })
    }
    
    # If we found a connection, process it
    if (is_db_connection) {
      # Check if it's currently valid
      if (!exists("is_valid") || is.na(is_valid)) {
        tryCatch({
          is_valid <- DBI::dbIsValid(obj)
        }, error = function(e) {
          is_valid <- FALSE
        })
      }
      
      # Store connection info
      conn_info <- list(
        name = obj_name,
        type = connection_type,
        valid = is_valid,
        object = obj
      )
      
      detected_connections[[obj_name]] <- conn_info
      
      # Report to console
      if (verbose) {
        status <- if (is_valid) "active" else "inactive"
        cat("  Found:", obj_name, "(", connection_type, ") -", status, "\n")
      }
      
      # Disconnect if requested and valid
      if (disconnect && is_valid) {
        tryCatch({
          DBI::dbDisconnect(obj)
          if (verbose) cat("    ✓ Disconnected:", obj_name, "\n")
          conn_info$disconnected <- TRUE
        }, error = function(e) {
          if (verbose) cat("    ⚠ Failed to disconnect:", obj_name, "-", e$message, "\n")
          conn_info$disconnected <- FALSE
        })
      }
    }
  }
  
  # Summary report
  if (verbose) {
    if (length(detected_connections) == 0) {
      cat("  No database connections detected\n")
    } else {
      active_count <- sum(sapply(detected_connections, function(x) x$valid))
      total_count <- length(detected_connections)
      
      if (disconnect) {
        disconnected_count <- sum(sapply(detected_connections, function(x) 
          isTRUE(x$disconnected)), na.rm = TRUE)
        cat("  Summary:", total_count, "connections found,", 
            disconnected_count, "successfully disconnected\n")
      } else {
        cat("  Summary:", total_count, "connections found,", 
            active_count, "currently active\n")
      }
    }
  }
  
  invisible(detected_connections)
}