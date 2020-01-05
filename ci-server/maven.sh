#!/bin/bash

source ./init-helper.sh
assert_command_exist mvn -v
install java.sh

# <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
# <html>
#  <head>
#   <title>Index of /apache/maven/maven-3</title>
#  </head>
#  <body>
# <h1>Index of /apache/maven/maven-3</h1>
# <pre><img src="/icons/blank.gif" alt="Icon "> <a href="?C=N;O=D">Name</a>                    <a href="?C=M;O=A">Last modified</a>      <a href="?C=S;O=A">Size</a>  <a href="?C=D;O=A">Description</a><hr><img src="/icons/back.gif" alt="[DIR]"> <a href="/apache/maven/">Parent Directory</a>                             -
# <img src="/icons/folder.gif" alt="[DIR]"> <a href="3.0.5/">3.0.5/</a>                  04-May-2018 19:18    -
# <img src="/icons/folder.gif" alt="[DIR]"> <a href="3.1.1/">3.1.1/</a>                  04-May-2018 19:19    -
# <img src="/icons/folder.gif" alt="[DIR]"> <a href="3.2.5/">3.2.5/</a>                  04-May-2018 19:19    -
# <img src="/icons/folder.gif" alt="[DIR]"> <a href="3.3.9/">3.3.9/</a>                  04-May-2018 19:19    -
# <img src="/icons/folder.gif" alt="[DIR]"> <a href="3.5.4/">3.5.4/</a>                  22-Jun-2018 04:33    -
# <img src="/icons/folder.gif" alt="[DIR]"> <a href="3.6.3/">3.6.3/</a>                  26-Nov-2019 02:16    -
# <hr></pre>
# </body></html>

echo "--- maven installing ---"
VERSION=$(curl -s http://mirror.bit.edu.cn/apache/maven/maven-3/ --compressed \
  |grep '<img src="/icons/folder.gif" alt="\[DIR\]">' \
  |awk '{print $5}' \
  |awk -F '"' '{print $2}' \
  |awk -F '/' '{print $1}' \
  |sort -rV \
  |sed -n '1p')
assert_status
echo "--- maven lastest version is $VERSION ---"

curl -O "http://mirror.bit.edu.cn/apache/maven/maven-3/$VERSION/binaries/apache-maven-$VERSION-bin.tar.gz"
assert_status
tar zxf apache-maven-$VERSION-bin.tar.gz
assert_status
rm -f apache-maven-$VERSION-bin.tar.gz
assert_status
check_directory /usr/share/maven-3
if [[ $? -eq 1 ]]; then
	rm -rf /usr/share/maven-3
fi
mv apache-maven-$VERSION /usr/share/maven-3
assert_status
echo 'MAVEN_HOME=/usr/share/maven-3' >> /etc/profile
assert_status
echo 'PATH=$PATH:$MAVEN_HOME/bin' >> /etc/profile
assert_status
source /etc/profile
assert_status
