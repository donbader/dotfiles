# dotfiles

### Bootstrap
```
git clone https://github.com/donbader/dotfiles ~/dotfiles
cd ~/dotfiles
./install
```

### Shared Env
```shell
export DOTFILES=$HOME/.dotfiles
export ZDOTDIR=$DOTFILES/zsh
```

### VS Code
```shell
# Update extensions list
./vscode/update_extensions.sh
```

### Mac OSX settings
```shell
# Import settings
./osx/settings
```

### Brew install
```shell
# Install Brewfile Apps
brew bundle
```
