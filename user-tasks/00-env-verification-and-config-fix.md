# Phase 0.5 – Environment Sanity Check + Config Fixes

**Owner:** M1 (Group Leader)
**Time needed:** 20–30 minutes
**Prerequisite:** Hadoop 3.2.1 already installed per Dr. Venkat's guide, WordCount ran successfully.

## Why this task exists

Dr. Venkat's install guide had three small issues copied verbatim into your VM's config. WordCount worked *despite* them because Hadoop fell back to defaults, but once we start loading the 3 GB taxi dataset and running Pig/Hive on top, they will cause real problems (under-replication errors, wrong NameNode metadata dir, native-lib warnings).

We fix them now, once, before touching data.

**All commands below run as user `hdoop` on the VM.**

---

## Step 1 — Stop all Hadoop daemons

```bash
$HADOOP_HOME/sbin/stop-yarn.sh
$HADOOP_HOME/sbin/stop-dfs.sh
jps    # should show only "Jps" itself now
```

Take a screenshot of the empty `jps` output (call it `00-stopped.png` — useful evidence in the report).

---

## Step 2 — Fix `hdfs-site.xml`

Open it:

```bash
vi $HADOOP_HOME/etc/hadoop/hdfs-site.xml
```

**Replace the entire `<configuration>…</configuration>` block with exactly this:**

```xml
<configuration>

  <!-- NameNode metadata storage (was wrongly using dfs.data.dir before) -->
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>/home/hdoop/dfsdata/namenode</value>
  </property>

  <!-- DataNode block storage -->
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>/home/hdoop/dfsdata/datanode</value>
  </property>

  <!-- Single-node cluster: replication factor must be 1, not 3 -->
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>

  <!-- Recommended for single-node: disable permission checks so Hive/Pig/HBase can write freely -->
  <property>
    <name>dfs.permissions.enabled</name>
    <value>false</value>
  </property>

</configuration>
```

**What changed vs Dr. Venkat's version:**
- His file had `dfs.data.dir` **twice** (the first pointing at the namenode dir). We split them into the correct property names: `dfs.namenode.name.dir` and `dfs.datanode.data.dir`.
- `dfs.replication` changed from `3` to `1` — mandatory for single-node.
- Added `dfs.permissions.enabled=false` so Hive/Pig/HBase can write to HDFS without hitting permission errors.

Save + quit: `:wq`

---

## Step 3 — Add memory limits to `mapred-site.xml` (crucial for 4 GB RAM)

```bash
vi $HADOOP_HOME/etc/hadoop/mapred-site.xml
```

**Replace the block with:**

```xml
<configuration>

  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>

  <!-- Small containers so we fit inside 4 GB VM -->
  <property>
    <name>mapreduce.map.memory.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.map.java.opts</name>
    <value>-Xmx410m</value>
  </property>
  <property>
    <name>mapreduce.reduce.java.opts</name>
    <value>-Xmx410m</value>
  </property>

  <property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.command-opts</name>
    <value>-Xmx410m</value>
  </property>

  <!-- Point YARN to the MR shuffle classpath (Hadoop 3.x needs this on some Ubuntu builds) -->
  <property>
    <name>mapreduce.application.classpath</name>
    <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
  </property>

</configuration>
```

Save + quit.

---

## Step 4 — Cap YARN memory in `yarn-site.xml`

```bash
vi $HADOOP_HOME/etc/hadoop/yarn-site.xml
```

**Replace with:**

```xml
<configuration>

  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>127.0.0.1</value>
  </property>
  <property>
    <name>yarn.acl.enable</name>
    <value>0</value>
  </property>
  <property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
  </property>

  <!-- Total memory YARN can hand out on this node — keep at 2 GB so OS + daemons have breathing room -->
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>256</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>1536</value>
  </property>

  <!-- Disable strict virtual-memory checks; low-RAM VMs otherwise kill containers -->
  <property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>false</value>
  </property>
  <property>
    <name>yarn.nodemanager.pmem-check-enabled</name>
    <value>false</value>
  </property>

</configuration>
```

Save + quit.

Also fix the whitelist typo (Dr. Venkat's file had `CLASSPATH_PERPEND_DISTCACHE` — the correct spelling is `CLASSPATH_PREPEND_DISTCACHE`). Already fixed in the block above.

---

## Step 5 — Fix the `.bashrc` typo

```bash
vi ~/.bashrc
```

Find the line:

```
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/nativ"
```

Change it to:

```
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
```

Save + quit, then reload:

```bash
source ~/.bashrc
env | grep HADOOP_OPTS   # should now show .../lib/native  (no missing 'e')
```

---

## Step 6 — Wipe old NameNode metadata and re-format

Because we changed the NameNode metadata property, the current directory contents may be stale. Fresh format is safest.

```bash
rm -rf /home/hdoop/dfsdata/namenode/*
rm -rf /home/hdoop/dfsdata/datanode/*
rm -rf /home/hdoop/tmpdata/*

hdfs namenode -format -force
```

At the end you should see:

```
Storage directory /home/hdoop/dfsdata/namenode has been successfully formatted.
```

If you don't — STOP and paste the error output back to Claude.

---

## Step 7 — Start daemons and verify

```bash
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
mapred --daemon start historyserver     # needed so Pig/Hive can read job counters
jps
```

You should see **all seven**:

```
NameNode
DataNode
SecondaryNameNode
ResourceManager
NodeManager
JobHistoryServer
Jps
```

The Job History Server listens on **IPC port 10020** and web UI **19888**. Without it, every Pig / Hive / MR job succeeds but you get 40+ lines of `Retrying connect to server: 0.0.0.0/0.0.0.0:10020` in the log after each run.

Screenshot this — call it `00-jps-healthy.png`.

---

## Step 8 — Sanity-check the file system

```bash
hdfs dfs -mkdir -p /tmp/hive-warehouse
hdfs dfs -mkdir -p /user/hdoop
hdfs dfs -mkdir -p /raw
hdfs dfs -mkdir -p /clean
hdfs dfs -mkdir -p /results
hdfs dfs -ls /
```

Expected output:

```
Found 5 items
drwxr-xr-x   - hdoop supergroup  0 ... /clean
drwxr-xr-x   - hdoop supergroup  0 ... /raw
drwxr-xr-x   - hdoop supergroup  0 ... /results
drwxr-xr-x   - hdoop supergroup  0 ... /tmp
drwxr-xr-x   - hdoop supergroup  0 ... /user
```

Screenshot: `00-hdfs-layout.png`.

Also open the NameNode UI (`http://localhost:9870`) and go to **Utilities → Browse the file system** — screenshot that too (`00-namenode-ui.png`).

---

## Step 9 — Re-run WordCount to confirm MR still works

```bash
cd
mkdir -p data_source && cd data_source
cat > data.txt <<'EOF'
transportation is the backbone of any economy
big data is transforming transportation
nyc yellow taxis run every day in transportation networks
transportation data helps city planners
EOF

hdfs dfs -mkdir -p /test/wordcount/input
hdfs dfs -put -f data.txt /test/wordcount/input/

cd $HADOOP_HOME/share/hadoop/mapreduce
hadoop jar hadoop-mapreduce-examples-3.2.1.jar wordcount \
  /test/wordcount/input /test/wordcount/output

hdfs dfs -cat /test/wordcount/output/part-r-00000
```

You should see word counts. Screenshot the output + the YARN UI (`http://localhost:8088`) showing the finished job — that's your first MR-job evidence for the report.

Clean up:

```bash
hdfs dfs -rm -r /test
```

---

## What to send back to Claude before moving to Phase 1

Paste (or attach screenshots of):

1. Output of `jps` from Step 7.
2. Output of `hdfs dfs -ls /` from Step 8.
3. Output of the wordcount job's last ~20 lines (the counters) from Step 9.
4. Any error message that stopped you at any step.

Once that's confirmed clean, we move to **`user-tasks/01-install-pig-hive-hbase.md`**.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `hdfs namenode -format` says "reformat? (Y or N)" | Old metadata left from earlier format | Answer `Y` — you already backed up nothing important. |
| `jps` missing DataNode | Cluster ID mismatch after re-format | `rm -rf /home/hdoop/dfsdata/datanode/*` then `start-dfs.sh` again. |
| `jps` missing NameNode | Config typo in `hdfs-site.xml` | Re-check Step 2 exactly; look at `$HADOOP_HOME/logs/hadoop-hdoop-namenode-*.log` for the specific parse error. |
| WordCount hangs at `map 0% reduce 0%` | Container too big for available memory | Confirm Steps 3 and 4 were saved. Run `yarn node -list` — memory should show ~2048. |
| Any command says "connection refused localhost:9000" | HDFS isn't up | Re-run `start-dfs.sh` and `jps`. |
| `WARN util.NativeCodeLoader: Unable to load native-hadoop library` | Cosmetic on Ubuntu 22.04 with JDK 8 | Ignore — it's a warning, not an error. |
