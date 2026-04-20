source("renv/activate.R")
options(save.workspace = "no")

if (interactive() && Sys.getenv("TERM_PROGRAM") == "vscode") {
  options(device = function(...) {
    if (requireNamespace("httpgd", quietly = TRUE)) {
      httpgd::hgd(...)
    } else {
      grDevices::png(...)
    }
  })
}
