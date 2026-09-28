# =========================================================================
# Additions to ~/.bashrc  for user `hdoop` on Ubuntu 22.04
# Assignment 1, Big Data Systems, BITS ZG522
#
# Contains: HADOOP + PIG + HIVE + HBASE environment
# Paste this block at the end of ~/.bashrc, then `source ~/.bashrc`
# =========================================================================

# --- JAVA ---
# Auto-detect JDK architecture (amd64 on Intel VMs, arm64 on Apple Silicon / ARM hosts).
# If dpkg is unavailable, falls back to whichever java-8-openjdk-* dir exists.
_JDK_ARCH="$(dpkg --print-architecture 2>/dev/null)"
if [ -z "$_JDK_ARCH" ] || [ ! -d "/usr/lib/jvm/java-8-openjdk-${_JDK_ARCH}" ]; then
    _JDK_ARCH="$(ls -d /usr/lib/jvm/java-8-openjdk-* 2>/dev/null | head -1 | sed 's|.*java-8-openjdk-||')"
fi
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-${_JDK_ARCH:-amd64}"
unset _JDK_ARCH

# --- HADOOP 3.2.1 ---
export HADOOP_HOME=/home/hdoop/hadoop-3.2.1
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin

# --- PIG 0.17.0 ---
export PIG_HOME=/home/hdoop/pig-0.17.0
export PATH=$PATH:$PIG_HOME/bin

# --- HIVE 3.1.3 ---
export HIVE_HOME=/home/hdoop/apache-hive-3.1.3-bin
export PATH=$PATH:$HIVE_HOME/bin

# --- HBASE 2.4.18 ---
export HBASE_HOME=/home/hdoop/hbase-2.4.18
export PATH=$PATH:$HBASE_HOME/bin

# --- Convenience shortcuts ---
alias jn='jps'
alias hstart='$HADOOP_HOME/sbin/start-dfs.sh && $HADOOP_HOME/sbin/start-yarn.sh && jps'
alias hstop='$HADOOP_HOME/sbin/stop-yarn.sh && $HADOOP_HOME/sbin/stop-dfs.sh && jps'
alias hls='hdfs dfs -ls'
alias hcat='hdfs dfs -cat'
