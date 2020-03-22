cat $(dirname $0)/vscode-extensions | grep -v '^#' | xargs -L1 code --install-extension
