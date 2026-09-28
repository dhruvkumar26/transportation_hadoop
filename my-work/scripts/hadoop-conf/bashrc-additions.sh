# =========================================================================
# Additions to ~/.bashrc  for user `hdoop` on Ubuntu 22.04
# Assignment 1, Big Data Systems, BITS ZG522
#
# Contains: HADOOP + PIG + HIVE + HBASE environment
# Paste this block at the end of ~/.bashrc, then `source ~/.bashrc`
# =========================================================================

# --- JAVA ---
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

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
