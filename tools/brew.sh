#!/bin/bash

RED=$(printf '\033[31m')
YELLOW=$(printf '\033[33m')
GREEN=$(printf '\033[32m')
RESET=$(printf '\033[m')
echo_error() {
  echo "${RED}error: $*${RESET}" >&2
}
echo_warn() {
  echo "${YELLOW}warn: $*${RESET}" >&2
}
echo_info() {
  echo "${GREEN}info: $*${RESET}" >&2
}

command_exists() {
  command -v "$*" >/dev/null 2>&1
}

# https://www.cnblogs.com/daodaotest/p/12635957.html
change_brew_git() {
  # 修改 brew.git 为阿里源
  git -C "$(brew --repo)" remote set-url origin https://mirrors.aliyun.com/homebrew/brew.git
  # 修改 homebrew-core.git 为阿里源
  git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.aliyun.com/homebrew/homebrew-core.git

  case $SHELL in
  '/bin/bash')
    # bash 替换 brew bintray 镜像
    echo 'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles' >>~/.bash_profile
    ;;
  '/bin/zsh')
    # zsh 替换 brew bintray 镜像
    echo 'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles' >>~/.zshrc
    ;;
  *)
    echo "不支持的shell(not /bin/zsh or /bin/zsh): $SHELL"
    exit 1
    ;;
  esac
  # 刷新源
  echo_info '正在刷新国内源, 请耐心等待'
  brew update

  case $SHELL in
  '/bin/bash')
    warn "请手动执行命令'source ~/.bash_profile'"
    ;;
  '/bin/zsh')
    warn "请手动执行命令'source ~/.zshrc'"
    ;;
  esac
}

command_exists brew || {
  info "正在为你安装依赖: brew"
  # Homebrew 国内自动安装脚本
  sh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
}

git -C "$(brew --repo)" remote -v | grep 'https://github.com/Homebrew/brew.git' -q
if [[ $? -eq 0 ]]; then
  echo_warn '当前brew为官方源, 安装依赖较慢, 正在为你切换到国内源'
  change_brew_git
else
  echo_info 'brew已安装并且为国内源'
fi
