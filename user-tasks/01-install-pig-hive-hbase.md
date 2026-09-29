# Phase 1 – Install Apache Pig, Hive & HBase

**Phase owner:** Dhruv (writes canonical steps) — Ramya, Sri Lalithya, Vishwa verify by reproducing on their VMs.
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

**DO NOT copy `hive-default.xml.template` to `hive-site.xml`.** That template contains its own `<property>javax.jdo.option.ConnectionURL</property>` with a *relative-path* Derby URL (`databaseName=metastore_db`). Hadoop XML config is **last-property-wins** — so if you add a second `ConnectionURL` on top, the template's original one silently overrides yours and Derby ends up creating a fresh, empty `metastore_db/` folder in whatever working directory you launch `hive` from. Every subsequent `CREATE TABLE` then fails with `Required table missing : "VERSION"`.

Instead, write a **minimal, single-source-of-truth `hive-site.xml`** — one `ConnectionURL`, no template inheritance:

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

**Verify — this must return exactly `2`** (one `<name>ConnectionURL</name>` + one `<value>…</value>`):

```bash
grep -c ConnectionURL $HIVE_HOME/conf/hive-site.xml
# → 2   ✓ correct
# → 4+  ✗ a template got merged in — nuke and rewrite the file
```

Also confirm the value has the **absolute** path:

```bash
grep -A 1 ConnectionURL $HIVE_HOME/conf/hive-site.xml
# expected:
#   <value>jdbc:derby:;databaseName=/home/hdoop/hive_metastore_db;create=true</value>
```

### 3e. Initialize the metastore schema

**Run this from your HOME directory** — schematool creates any incidental files (`derby.log`) in the current working directory, so running it under a project folder litters that folder:

```bash
cd ~
schematool -dbType derby -initSchema 2>&1 | tail -5
```

Expected last lines:

```
Metastore connection URL:  jdbc:derby:;databaseName=/home/hdoop/hive_metastore_db;create=true
...
Initialization script completed
schemaTool completed
```

**The `Metastore connection URL` line MUST show the absolute `/home/hdoop/hive_metastore_db` path.** If it says `databaseName=metastore_db` (no path), your `hive-site.xml` is being overridden by a template copy — redo Step 3d.

Verify the metastore is where it should be:

```bash
ls -la /home/hdoop/hive_metastore_db | head -3
# expected: shows a Derby database directory (seg0, service.properties, tmp, etc.)
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

## Reproduce checklist (for Ramya, Sri Lalithya, Vishwa running the same steps on their VM)

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
| `Required table missing : "VERSION"` when running a `CREATE`/`INSERT` after DDL, even though `SHOW DATABASES` worked | `hive-site.xml` has two `ConnectionURL` properties — the template's relative-path one silently overrode yours, so Derby is creating empty `metastore_db/` dirs in whatever cwd `hive` was launched from | Nuke every stale metastore + rewrite hive-site.xml as single-source minimal file:<br/>`rm -rf /home/hdoop/hive_metastore_db /home/hdoop/metastore_db`<br/>`find ~ -maxdepth 6 -name "metastore_db" -type d \| xargs rm -rf`<br/>`find ~ -maxdepth 6 \( -name derby.log -o -name '*.lck' \) \| xargs rm -f`<br/>Redo Step 3d exactly, then Step 3e |
| Derby creates fresh empty `metastore_db/` in every directory you cd into | Same as above — duplicate `ConnectionURL` in hive-site.xml means the relative-path (template) one wins | Same fix as above |
| HBase `HMaster` not showing in `jps` | Port 16000/16010 already used | Check with `sudo lsof -i :16010`; kill offender |
| HBase can't connect to HDFS | Hadoop is stopped | `start-dfs.sh && start-yarn.sh` first |
| `WARN util.NativeCodeLoader` when running anything | Native lib warning | Ignore — cosmetic |
| `HADOOP_ORG.APACHE.HADOOP.HBASE.UTIL.GETJAVAPROPERTY_USER: invalid variable name` | HBase 2.4 on Hadoop 3.x classpath probe bug | Add `export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP="true"` to `hbase-env.sh` |
| `$JAVA_HOME/bin/java: No such file or directory` when starting HBase | Wrong arch in `JAVA_HOME` (VM is ARM64 but path says amd64, or vice versa) | Check `dpkg --print-architecture`; fix path in `~/.bashrc` **and** `hbase-env.sh`; then `source ~/.bashrc` and retry |
