#!/bin/bash

# set -euxo pipefail

function zsh_plugin {
  URL=$1
  NAME=$(echo $URL |awk -F '/' '{print $NF}' |awk -F '.' '{print $(NF-1)}')
  if [[ ! -d ~/.oh-my-zsh/plugins/$NAME ]]; then
    git clone --depth 1 $URL ~/.oh-my-zsh/plugins/$NAME
  fi
  if [[ $(sed -n "/$NAME/p" ~/.zshrc) = '' ]]; then
    sed -i "s/^plugins=([^)]*/& $NAME/" ~/.zshrc
  fi
}

chsh -s /bin/zsh
echo 'yes' |sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"

# plugins
zsh_plugin https://github.com/zsh-users/zsh-autosuggestions.git
zsh_plugin https://github.com/zsh-users/zsh-completions.git
zsh_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git

# powerline
command -v pip
if [[ $? -eq 1 ]]; then
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python get-pip.py
  rm -rf get-pip.py
fi
command -v fc-cache
if [[ $? -eq 1 ]]; then
  yum install -y fontconfig
fi
mkdir -p /user/share/fonts
curl https://gitee.com/mirrors/Powerline/raw/master/font/PowerlineSymbols.otf -o PowerlineSymbols.otf
mv PowerlineSymbols.otf /user/share/fonts/
curl https://gitee.com/mirrors/Powerline/raw/master/font/10-powerline-symbols.conf -o 10-powerline-symbols.conf
mkdir -p /etc/fonts/conf.d
mv 10-powerline-symbols.conf /etc/fonts/conf.d/
fc-cache -vf /usr/share/fonts
pip install powerline-status
grep -q 'powerline-daemon -q' ~/.zshrc
if [[ $? -eq 1 ]]; then
  cat <<EOF >> ~/.zshrc

# powerline
if [ -f `which powerline-daemon` ];then
  powerline-daemon -q
  POWERLINE_BASH_CONTINUATION=1
  POWERLINE_BASH_SELECT=1
  . /usr/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh
fi
export TERM="screen-256color"
EOF
fi

zsh
