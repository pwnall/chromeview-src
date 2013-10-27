#!/bin/sh
# Idempotent VM setup / upgrade script.

set -o errexit  # Stop the script on the first error.
set -o nounset  # Catch un-initialized variables.

# Enable password-less sudo for the current user.
sudo sh -c "echo '$USER ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/$USER"
sudo chmod 0400 /etc/sudoers.d/$USER

# Sun JDK 6.
if [ ! -f /usr/bin/javac ] ; then
  if [ ! -f ~/jdk6.bin ] ; then
    echo 'Please download the Linux x86 non-RPM JDK6 as jdk6.bin from'
    echo 'http://www.oracle.com/technetwork/java/javase/downloads/index.html'
    exit 1
  fi

  sudo mkdir -p /usr/lib/jvm
  cd /usr/lib/jvm
  sudo /bin/sh ~/jdk6.bin -noregister
  rm ~/jdk6.bin
  sudo update-alternatives --install /usr/bin/javac javac \
      /usr/lib/jvm/jdk1.6.0_*/bin/javac 50000
  sudo update-alternatives --config javac
  sudo update-alternatives --install /usr/bin/java java \
      /usr/lib/jvm/jdk1.6.0_*/bin/java 50000
  sudo update-alternatives --config java
  sudo update-alternatives --install /usr/bin/javaws javaws \
      /usr/lib/jvm/jdk1.6.0_*/bin/javaws 50000
  sudo update-alternatives --config javaws
  sudo update-alternatives --install /usr/bin/javap javap \
      /usr/lib/jvm/jdk1.6.0_*/bin/javap 50000
  sudo update-alternatives --config javap
  sudo update-alternatives --install /usr/bin/jar jar \
      /usr/lib/jvm/jdk1.6.0_*/bin/jar 50000
  sudo update-alternatives --config jar
  sudo update-alternatives --install /usr/bin/jarsigner jarsigner \
      /usr/lib/jvm/jdk1.6.0_*/bin/jarsigner 50000
  sudo update-alternatives --config jarsigner
  cd ~/
fi

# When upgrading, keep modified configuration files, overwrite unmodified ones.
sudo tee /etc/apt/apt.conf.d/90-no-prompt > /dev/null <<'EOF'
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
EOF

# Enable the multiverse reposistory, for ttf-mscorefonts-installer.
sudo sed -i "/^# deb.*multiverse/ s/^# //" /etc/apt/sources.list

# Update all system packages.
sudo apt-get update -qq
sudo apt-get -y dist-upgrade

# debconf-get-selections is useful for figuring out debconf defaults.
sudo apt-get install -y debconf-utils

# Quiet all package installation prompts.
sudo debconf-set-selections <<'EOF'
debconf debconf/frontend select Noninteractive
debconf debconf/priority select critical
EOF

# Web server for the builds.
sudo apt-get install -y apache2
sudo mkdir -p /etc/apache2/sites-available
sudo tee /etc/apache2/sites-available/001-crbuilds.conf > /dev/null <<EOF
<VirtualHost *:80>
	ServerAdmin webmaster@localhost

	DocumentRoot /home/$USER/crbuild.www
	<Directory />
		Options FollowSymLinks
		AllowOverride None
	</Directory>
	<Directory /home/$USER/crbuild.www>
		Options Indexes FollowSymLinks MultiViews
		AllowOverride None
		Order allow,deny
		allow from all
	</Directory>

	ErrorLog /var/log/apache2/error.log
	LogLevel warn
	CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF
sudo ln -s -f /etc/apache2/sites-available/001-crbuilds.conf \
              /etc/apache2/sites-enabled/001-crbuilds.conf
sudo rm -f /etc/apache2/sites-enabled/*default
sudo /etc/init.d/apache2 restart

# Git.
sudo apt-get install -y git

# Depot tools.
# http://dev.chromium.org/developers/how-tos/install-depot-tools
cd ~
if [ -d ~/depot_tools ] ; then
  cd ~/depot_tools
  git pull origin master
  cd ~
fi
if [ ! -d ~/depot_tools ] ; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
if ! grep -q 'export PATH=$PATH:$HOME/depot_tools' ~/.bashrc ; then
  echo 'export PATH=$PATH:$HOME/depot_tools' >> ~/.bashrc
  export PATH=$PATH:$HOME/depot_tools
fi

# Subversion and git-svn.
sudo apt-get install -y git-svn subversion

# Chromium build setup.
# https://code.google.com/p/chromium/wiki/LinuxBuildInstructions
# https://code.google.com/p/chromium/wiki/AndroidBuildInstructions

# Chromium build depedenecies not covered by the Chromium scripts.
sudo apt-get install -y ia32-libs libc6-dev-i386 g++-multilib

# Chromium source.
# https://code.google.com/p/chromium/wiki/UsingGit
# http://dev.chromium.org/developers/how-tos/get-the-code
if [ ! -d ~/chromium ] ; then
  if [ ! -z $CRBUILD_DIR ] ; then
    sudo mkdir -p "$CRBUILD_DIR"
    sudo mkdir -p "$CRBUILD_DIR/chromium"
    sudo mkdir -p "$CRBUILD_DIR/crbuild.www"
    sudo chown $USER "$CRBUILD_DIR"
    sudo chown $USER "$CRBUILD_DIR/chromium"
    sudo chown $USER "$CRBUILD_DIR/crbuild.www"
    chmod 0755 "$CRBUILD_DIR"
    chmod 0755 "$CRBUILD_DIR/chromium"
    chmod 0755 "$CRBUILD_DIR/crbuild.www"
    ln -s "$CRBUILD_DIR/chromium" ~/chromium
    ln -s "$CRBUILD_DIR/crbuild.www" ~/crbuild.www
  fi
  if [ -z "$CRBUILD_DIR" ] ; then
    mkdir -p ~/chromium
    mkdir -p ~/crbuild.www
  fi
fi
cd  ~/chromium
if [ ! -f .gclient ] ; then
  ~/depot_tools/fetch android --nosvn=True || \
      echo "Ignore the error above if this is a first-time setup"
fi
cd ~/chromium/src
sudo ./build/install-build-deps-android.sh
yes | sudo ./build/install-build-deps.sh --no-syms --arm --lib32

cd ~/chromium

set +o nounset  # Chromium scripts are messy.
. src/build/android/envsetup.sh  # "source" is bash-only, whereas "." is POSIX.
set -o nounset  # Catch un-initialized variables.
gclient runhooks || \
    echo "Ignore the error above if this is a first-time setup"
