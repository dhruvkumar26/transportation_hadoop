# Phase 1 – Install Apache Pig, Hive & HBase

**Phase owner:** M1 (writes canonical steps) — M4, M5, M6 verify by reproducing on their VMs.
**Time:** 45–60 minutes total across the three tools.
**Prerequisite:** Phase 0.5 clean (Hadoop 3.2.1 pseudo-cluster verified with WordCount).

## What we're installing (versions locked to Hadoop 3.2.1)

| Tool | Version | Download |
|---|---|---|
| Apache Pig | **0.17.0** | `https://archive.apache.org/dist/pig/pig-0.17.0/pig-0.17.0.tar.gz` |
| Apache Hive | **3.1.3** | `https://archive.apache.org/dist/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz` |
| Apache HBase | **2.4.18** | `https://archive.apache.org/dist/hbase/2.4.18/hbase-2.4.18-bin.tar.gz` |

These three versions have known compatibility with Hadoop 3.2.1.

**All commands run as `hdoop` on the VM.**

---

## Step 1 — Ensure `.bashrc` has the environment additions

Paste the block from `my-work/scripts/hadoop-conf/bashrc-additions.sh` at the end of your `~/.bashrc`, then:

```bash
source ~/.bashrc
env | grep -E "HADOOP_HOME|PIG_HOME|HIVE_HOME|HBASE_HOME"
```

Expected:

```
HADOOP_HOME=/home/hdoop/hadoop-3.2.1
PIG_HOME=/home/hdoop/pig-0.17.0
HIVE_HOME=/home/hdoop/apache-hive-3.1.3-bin
HBASE_HOME=/home/hdoop/hbase-2.4.18
```

(The dirs don't exist yet — that's fine; we'll create them.)

---

## Step 2 — Install Apache Pig 0.17.0

```bash
cd ~
wget https://archive.apache.org/dist/pig/pig-0.17.0/pig-0.17.0.tar.gz
tar xzf pig-0.17.0.tar.gz
rm pig-0.17.0.tar.gz     # save disk
```

Verify:

```bash
pig -version
```

Expected (first line):

```
Apache Pig version 0.17.0 (r1797386)
```

Screenshot this — `01-pig-version.png`.

---

## Step 3 — Install Apache Hive 3.1.3

### 3a. Download and extract

```bash
cd ~
wget https://archive.apache.org/dist/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz
tar xzf apache-hive-3.1.3-bin.tar.gz
rm apache-hive-3.1.3-bin.tar.gz
```

### 3b. Fix Guava conflict (well-known Hive 3.1.3 issue)

Hive 3.1.3 ships an old Guava that conflicts with Hadoop 3.2.1's newer one. Replace it:

```bash
rm $HIVE_HOME/lib/guava-19.0.jar
cp $HADOOP_HOME/share/hadoop/hdfs/lib/guava-27.0-jre.jar $HIVE_HOME/lib/
```

### 3c. Create HDFS dirs Hive needs

```bash
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -mkdir -p /tmp
hdfs dfs -chmod -R 1777 /tmp
hdfs dfs -chmod -R 1777 /user/hive/warehouse
```

### 3d. Configure Hive to use embedded Derby metastore

```bash
cp $HIVE_HOME/conf/hive-default.xml.template $HIVE_HOME/conf/hive-site.xml
```

Open `hive-site.xml` and add these properties **inside the `<configuration>` root**, at the top (before the auto-generated ones):

```xml
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:derby:;databaseName=/home/hdoop/hive_metastore_db;create=true</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>/user/hive/warehouse</value>
  </property>
  <property>
    <name>system:java.io.tmpdir</name>
    <value>/tmp/hive</value>
  </property>
  <property>
    <name>system:user.name</name>
    <value>hdoop</value>
  </property>
```

Also, edit `hive-site.xml` and search for `hive.txn.xlock.iow` — there is a bad `&#8;` character in the template's description that breaks XML parsing on some builds. Remove or replace with plain text.

Simpler alternative — a minimal `hive-site.xml`:

```bash
cat > $HIVE_HOME/conf/hive-site.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:derby:;databaseName=/home/hdoop/hive_metastore_db;create=true</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.apache.derby.jdbc.EmbeddedDriver</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>/user/hive/warehouse</value>
  </property>
  <property>
    <name>hive.exec.scratchdir</name>
    <value>/tmp/hive</value>
  </property>
</configuration>
EOF
```

### 3e. Initialize the metastore schema

```bash
schematool -dbType derby -initSchema
```

Expected last line:

```
Initialization script completed
schemaTool completed
```

### 3f. Smoke test

```bash
hive -e "SHOW DATABASES;"
```

Expected:

```
OK
default
Time taken: ... seconds
```

Screenshot: `01-hive-show-databases.png`.

---

## Step 4 — Install Apache HBase 2.4.18 (standalone mode)

```bash
cd ~
wget https://archive.apache.org/dist/hbase/2.4.18/hbase-2.4.18-bin.tar.gz
tar xzf hbase-2.4.18-bin.tar.gz
rm hbase-2.4.18-bin.tar.gz
```

### 4a. Point HBase's `hbase-env.sh` at Java

**First determine your VM's architecture** (Intel = `amd64`, Apple Silicon / ARM host = `arm64`):

```bash
dpkg --print-architecture
# or, equivalently:
ls -d /usr/lib/jvm/java-8-openjdk-*
```

Use the value you see (`amd64` or `arm64`) in the next commands.

```bash
vi $HBASE_HOME/conf/hbase-env.sh
```

Add near the top (replace `<ARCH>` with `amd64` or `arm64`):

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-<ARCH>
export HBASE_MANAGES_ZK=true

# HBase 2.4 + Hadoop 3.x compat — skips a broken classpath-lookup step
# whose sysprop names contain dots that bash rejects.
export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP="true"
```

**Verify** the java binary actually lives at that path (JDK 8 keeps `java` inside a `jre` subdirectory):

```bash
ls -la $JAVA_HOME/jre/bin/java     # must exist — this is what HBase invokes
ls -la $JAVA_HOME/bin/javac        # must exist too
```

### 4b. Configure standalone HBase using HDFS

```bash
cat > $HBASE_HOME/conf/hbase-site.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://127.0.0.1:9000/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/home/hdoop/zookeeper</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>false</value>
  </property>
  <property>
    <name>hbase.unsafe.stream.capability.enforce</name>
    <value>false</value>
  </property>
</configuration>
EOF
```

### 4c. Start HBase

**Important — Hive and HBase together will not fit in 4 GB RAM. Stop Hive-related processes first, and only start HBase when you need it.**

```bash
start-hbase.sh
jps
```

Expected extra processes:

```
HMaster
HRegionServer
HQuorumPeer
```

### 4d. Smoke test the shell

```bash
echo "list" | hbase shell 2>/dev/null | tail -5
```

Expected (no tables yet):

```
TABLE
0 row(s) in ... seconds

=> []
```

Web UI: `http://localhost:16010` — screenshot as `01-hbase-master-ui.png`.

### 4e. Stop HBase for now (memory management)

```bash
stop-hbase.sh
jps       # HMaster/HRegionServer/HQuorumPeer gone
```

---

## Step 5 — Save evidence and hand off

Screenshots to add to the shared repo (`screenshots/phase-1/<memberID>/`):

| File | What it shows |
|---|---|
| `01-pig-version.png` | `pig -version` output |
| `01-hive-show-databases.png` | `SHOW DATABASES` succeeding |
| `01-hbase-master-ui.png` | HBase Master UI at :16010 |

Paste back to Claude:

1. Output of `pig -version`
2. Output of `hive -e "SHOW DATABASES;"`
3. Output of `echo "list" | hbase shell` (from Step 4d)
4. Any error message that stopped you

Once verified, we move to **`02-download-and-ingest.md`**.

---

## Reproduce checklist (for M4, M5, M6 running the same steps on their VM)

- [ ] `.bashrc` block appended and sourced.
- [ ] Pig extracted to `/home/hdoop/pig-0.17.0`; `pig -version` prints 0.17.0.
- [ ] Hive extracted to `/home/hdoop/apache-hive-3.1.3-bin`.
- [ ] Guava swap done (old `guava-19.0.jar` gone, `guava-27.0-jre.jar` present).
- [ ] `hive-site.xml` created with the minimal block.
- [ ] `schematool -dbType derby -initSchema` succeeded.
- [ ] `hive -e "SHOW DATABASES;"` prints `default`.
- [ ] HBase extracted to `/home/hdoop/hbase-2.4.18`.
- [ ] `hbase-site.xml` created; `start-hbase.sh` starts HMaster/HRegionServer/HQuorumPeer.
- [ ] Web UI at `:16010` reachable.
- [ ] `stop-hbase.sh` cleanly shuts everything back down.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `hive` command not found | `~/.bashrc` not sourced this shell | `source ~/.bashrc` |
| `schematool` fails with `Underlying cause: java.sql.SQLException: Failed to create database` | Leftover `metastore_db` | `rm -rf /home/hdoop/hive_metastore_db metastore_db` then re-run |
| `hive` throws `java.lang.NoSuchMethodError ... Preconditions.checkArgument` | Guava conflict not fixed | Redo Step 3b exactly |
| `SAXParseException` when starting `hive` | Bad `&#8;` in `hive-default.xml.template` | Use the minimal `hive-site.xml` in Step 3d |
| HBase `HMaster` not showing in `jps` | Port 16000/16010 already used | Check with `sudo lsof -i :16010`; kill offender |
| HBase can't connect to HDFS | Hadoop is stopped | `start-dfs.sh && start-yarn.sh` first |
| `WARN util.NativeCodeLoader` when running anything | Native lib warning | Ignore — cosmetic |
| `HADOOP_ORG.APACHE.HADOOP.HBASE.UTIL.GETJAVAPROPERTY_USER: invalid variable name` | HBase 2.4 on Hadoop 3.x classpath probe bug | Add `export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP="true"` to `hbase-env.sh` |
| `$JAVA_HOME/bin/java: No such file or directory` when starting HBase | Wrong arch in `JAVA_HOME` (VM is ARM64 but path says amd64, or vice versa) | Check `dpkg --print-architecture`; fix path in `~/.bashrc` **and** `hbase-env.sh`; then `source ~/.bashrc` and retry |
