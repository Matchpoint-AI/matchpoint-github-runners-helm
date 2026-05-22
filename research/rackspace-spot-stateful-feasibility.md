# Rackspace Spot: Stateful Workload Feasibility for Hermes Agents

**Date:** 2026-05-22
**Author:** Claude (automated research)
**Cluster:** matchpoint-agents (us-east-iad-1)
**Status:** CONDITIONAL GO -- see Section 6

---

## TL;DR

Rackspace Spot *can* host stateful Hermes agent workloads. The platform provides network-attached Cinder block storage (PVCs survive node preemption) and a 5-minute preemption grace period. However, the current `matchpoint-agents` cloudspace has a **SubscriptionSuspended** status that must be resolved first. The recommended StorageClass is `ssd` (Cinder SSD) or, if available, `spot-ceph` (faster attach/detach). Cost is dramatically lower than Hetzner: ~$15-29/mo vs ~EUR 35-50/mo.

---

## 1. StorageClass Inventory

Captured via `KUBECONFIG=matchpoint-agents.yaml kubectl get sc -o yaml` on 2026-05-22.

| StorageClass | Provisioner | Cinder Type | ReclaimPolicy | VolumeBindingMode | AllowExpansion | Access Modes | Backing | Default |
|---|---|---|---|---|---|---|---|---|
| **ssd** | `cinder.csi.openstack.org` | M1 | Delete | Immediate | not set (false) | RWO | Network block (OpenStack Cinder SSD) | **Yes** |
| **ssd-large** | `cinder.csi.openstack.org` | ssd | Delete | Immediate | not set (false) | RWO | Network block (Cinder SSD, large pool) | No |
| **sata** | `cinder.csi.openstack.org` | M4 | Delete | Immediate | not set (false) | RWO | Network block (Cinder SATA) | No |
| **sata-large** | `cinder.csi.openstack.org` | sata | Delete | Immediate | not set (false) | RWO | Network block (Cinder SATA, large pool) | No |

**Notable absence:** The `spot-ceph` StorageClass (Ceph RBD-backed, documented in [Rackspace Spot's blog](https://spot.rackspace.com/blog/cinder-csi-vs-ceph-rbd-csi-in-kubernetes-an-analysis-of-persistent-volume-lifecycle-performance-on-rackspace-spot)) is **not present** on this cluster. This matters because Ceph RBD attach/detach is 13-78x faster than Cinder (see Section 2).

**CSI driver installed:** `cinder.csi.openstack.org` (supports Persistent and Ephemeral modes).

**No VolumeSnapshot CRDs** are registered on the cluster (`kubectl api-resources | grep snapshot` returns nothing). This impacts the backup story (Section 4).

### Per-GiB Pricing

Rackspace Spot does not publish per-GiB storage pricing in their public docs or CLI. This is an open question (see Section 7). For reference, Rackspace Cloud Block Storage (legacy) was ~$0.15/GiB/mo for SSD. At 7 GiB total for Hermes, storage cost is likely <$2/mo regardless of tier.

### Raw kubectl output

```yaml
# kubectl get sc -o yaml (abbreviated)
- name: ssd          provisioner: cinder.csi.openstack.org  parameters.type: M1    (default)
- name: ssd-large    provisioner: cinder.csi.openstack.org  parameters.type: ssd
- name: sata         provisioner: cinder.csi.openstack.org  parameters.type: M4
- name: sata-large   provisioner: cinder.csi.openstack.org  parameters.type: sata
```

---

## 2. Preemption Durability Test

### Status: NOT EXECUTED -- cluster SubscriptionSuspended

The `matchpoint-agents` cloudspace is in `SubscriptionSuspended` status with 0 nodes. The `mp-runners-v4` cloudspace no longer exists in the Spot inventory. Without running nodes, the PVC attach/preemption test cannot be performed.

```json
// spotctl cloudspaces list (abbreviated)
{
  "name": "matchpoint-agents",
  "status": "Error",
  "message": "SubscriptionSuspended",
  "spotNodepools": [{
    "status": "SubscriptionSuspended",
    "autoscaling": { "enabled": false, "minNodes": 0, "maxNodes": 0 },
    "bidPrice": "$0.300"
  }]
}
```

### What we know from Rackspace's own benchmarks

From Rackspace Spot's [Cinder vs Ceph RBD blog post](https://spot.rackspace.com/blog/cinder-csi-vs-ceph-rbd-csi-in-kubernetes-an-analysis-of-persistent-volume-lifecycle-performance-on-rackspace-spot), which tested the exact preemption-and-reattach scenario:

| Operation | Cinder (ssd) | Ceph RBD (spot-ceph) |
|---|---|---|
| Initial PVC attach | 78 seconds | ~1 second |
| PVC detach | 75 seconds | 10 seconds |
| PVC reattach to new node | 76 seconds | ~1 second |
| **End-to-end pod reschedule** | **151 seconds** | **11 seconds** |

**Key findings from the blog:**
- Cinder volumes *do* survive preemption and reattach to new nodes (they are network-attached block storage, independent of the compute node)
- Cinder reattach involves 5 control plane layers (K8s -> CSI driver -> Cinder -> Nova -> Hypervisor) causing 76-second delays with retry loops
- Ceph RBD communicates directly with the storage cluster, eliminating these delays
- Data integrity was preserved across all tested reattach cycles

### Expected behavior for Hermes (based on Rackspace data)

With the `ssd` StorageClass (Cinder):
1. Preemption triggers pod eviction (5-minute grace period)
2. preStop hook runs, SQLite WAL checkpoint completes, process exits cleanly
3. Node removed from cluster
4. Pod rescheduled to surviving/new node
5. **PVC reattach takes ~76 seconds** (Cinder retry loop)
6. Pod starts, mounts existing data
7. **Total downtime: ~2.5 minutes** (151s per Rackspace benchmarks)

With `spot-ceph` (if available):
7. **Total downtime: ~11 seconds**

---

## 3. Preemption Notification Window

### Rackspace Spot: 5-minute preemption notice

Source: Rackspace Spot documentation and [Airflow on Spot blog](https://spot.rackspace.com/blog/building-fault-tolerant-airflow-pipelines-on-spot-infrastructure).

**Preemption sequence:**
1. **T+0:00** -- Termination notice sent to node
2. **T+0:00** -- Node is cordoned (no new pods scheduled)
3. **T+0:00 to T+terminationGracePeriodSeconds** -- Pods receive SIGTERM, preStop hooks execute
4. **T+terminationGracePeriodSeconds** -- SIGKILL sent to remaining processes
5. **T+5:00** -- Node removed from cluster

**Budget for preStop hook:** Up to `terminationGracePeriodSeconds` (configurable per pod, default 30s in K8s). With a 5-minute platform window, you can safely set `terminationGracePeriodSeconds: 300` (the full 5 minutes).

**Preemption rate:** <1% per Rackspace documentation. Above-median bidding further reduces this.

### Recommended Hermes config

```yaml
spec:
  terminationGracePeriodSeconds: 120  # 2 min for SQLite WAL checkpoint + token cache flush
  containers:
  - name: hermes
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            # Signal Hermes to flush SQLite WAL and close DB connections
            kill -SIGTERM 1
            # Wait for graceful shutdown
            sleep 30
```

This leaves 3 minutes of buffer within the 5-minute platform window for unexpected delays.

---

## 4. Backup Story

### VolumeSnapshots: NOT AVAILABLE

The cluster has no VolumeSnapshot CRDs registered:

```
$ kubectl api-resources | grep snapshot
(no output)
```

The Cinder CSI driver (`cinder.csi.openstack.org`) supports snapshots in principle (OpenStack Cinder supports volume snapshots), but Rackspace Spot has not deployed the CSI snapshotter sidecar or registered the CRDs.

### Alternative backup strategies

**Option A: `kubectl cp` to GCS (recommended)**

```bash
# From a CronJob or external script
kubectl cp hermes-reeve:/opt/hermes-data/ /tmp/hermes-backup-reeve/
gsutil rsync -r /tmp/hermes-backup-reeve/ gs://matchpoint-hermes-backups/reeve/$(date +%Y%m%d)/
```

- Time for 1 GiB: ~30-60 seconds (network-bound)
- Survives cluster deletion (data is in GCS)
- Cost: GCS Standard ~$0.02/GiB/mo = ~$0.14/mo for 7 agents

**Option B: Restic/Velero to GCS**

Velero with Restic can back up PVCs on a schedule. However, Velero's CSI snapshot integration won't work without VolumeSnapshot CRDs, so it would use file-level backup (restic) instead.

**Option C: Application-level SQLite backup**

SQLite's `.backup` command or `VACUUM INTO` can create a consistent snapshot while the database is in use. This is the safest option for SQLite specifically:

```bash
sqlite3 /opt/hermes-data/hermes.db "VACUUM INTO '/opt/hermes-data/backup-$(date +%s).db'"
```

### What happens to PVCs when the cluster is deleted?

Cinder volumes with `reclaimPolicy: Delete` are **destroyed when the PVC is deleted**. If the cluster is deleted, all PVCs and their backing Cinder volumes are also deleted. **External backups (GCS) are essential.**

### Snapshot pricing

N/A -- VolumeSnapshots not available. GCS backup cost is ~$0.02/GiB/mo.

---

## 5. Cost Model

### Compute: Hermes agent requirements

- 7 containers x 1.5 GiB RAM = 10.5 GiB working RAM
- CPU: low (agents are I/O-bound, not CPU-bound)
- Need: 2 nodes with enough RAM for 3-4 agents each + system overhead

### Recommended server class: `gp.vs1.large-iad`

| Attribute | Value |
|---|---|
| CPU | 4 vCPU |
| Memory | 15 GiB |
| Region | us-east-iad-1 |
| Current market price | $0.001/hr |
| Minimum bid | $0.010/hr |
| On-demand price | $0.075/hr |

### Pricing scenarios (2 nodes, 730 hrs/mo)

| Bid strategy | Per-node $/hr | Monthly (2 nodes) | vs Hetzner (EUR 35-50) |
|---|---|---|---|
| Market price ($0.001) | $0.001 | **$1.46** | 97% savings |
| Minimum bid ($0.010) | $0.010 | **$14.60** | 58-71% savings |
| Above-median ($0.020) | $0.020 | **$29.20** | 17-42% savings |
| Above-median ($0.030) | $0.030 | **$43.80** | ~break-even |
| On-demand ($0.075) | $0.075 | **$109.50** | 2-3x more expensive |

**Note:** The existing nodepool has `bidPrice: $0.300/hr` which is 4x the on-demand price -- this is excessive and likely a mistake from initial setup.

### Storage cost (estimated)

7 PVCs x 1 GiB x ~$0.15/GiB/mo = ~$1.05/mo (estimate; actual Spot pricing not published).

### Recommendation

**Bid at $0.020/hr (above median)** for stability with good savings. Total estimated cost:

| Component | Monthly cost |
|---|---|
| Compute (2x gp.vs1.large-iad @ $0.020/hr) | $29.20 |
| Storage (7x 1 GiB SSD PVC) | ~$1.05 |
| Backup (7 GiB GCS) | ~$0.14 |
| **Total** | **~$30.39** |

vs Hetzner current: EUR 35/mo, projected EUR 40-50/mo. **Spot is 15-40% cheaper at above-median bid, with the benefit of managed Kubernetes.**

---

## 6. Go / No-Go Recommendation

### CONDITIONAL GO

Rackspace Spot is architecturally suitable for stateful Hermes agents, **but two blockers must be resolved first:**

#### Blocker 1: SubscriptionSuspended (CRITICAL)

The `matchpoint-agents` cloudspace is in `SubscriptionSuspended` state. No nodes can be provisioned. This must be resolved with Rackspace support before any workloads can run.

**Severity:** P0 -- nothing works until this is resolved.

#### Blocker 2: Preemption durability test not validated (HIGH)

Rackspace's own benchmarks confirm Cinder PVCs survive preemption and reattach, but we have not validated this on our specific cluster. Once Blocker 1 is resolved, the test from Section 2 should be executed before migrating production agents.

**Severity:** P1 -- high confidence from vendor data, but must verify.

### If blockers are resolved, use this configuration:

| Parameter | Value |
|---|---|
| **Cloudspace** | matchpoint-agents (us-east-iad-1) |
| **Server class** | gp.vs1.large-iad (4 CPU, 15 GiB) |
| **Node count** | 2 (7 agents across 2 nodes) |
| **Bid price** | $0.020/hr (above median, 2x min bid) |
| **StorageClass** | `ssd` (default, Cinder SSD) -- or request `spot-ceph` from Rackspace for 13x faster reattach |
| **PVC size** | 1 GiB per agent (7 PVCs) |
| **terminationGracePeriodSeconds** | 120 |
| **preStop hook** | SIGTERM + 30s sleep for SQLite WAL checkpoint |
| **Backup** | CronJob: `kubectl cp` -> GCS, daily |
| **PVC reclaimPolicy** | Change to `Retain` (override default `Delete`) to prevent accidental data loss |

### Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Node preempted, PVC reattaches slowly (Cinder: ~2.5 min) | Low (<1% preemption rate) | Medium (agent offline 2.5 min) | Above-median bid; request spot-ceph |
| PVC data lost during cluster deletion | Low | **Critical** | Daily GCS backup; reclaimPolicy=Retain |
| SQLite corruption during ungraceful shutdown | Very low | High | preStop hook + WAL checkpoint; 120s grace |
| Subscription suspended again | Unknown | Critical | Understand root cause with Rackspace |
| Cinder volume stuck in transitional state | Low | Medium | Manual intervention via OpenStack API |

---

## 7. Open Questions

1. **Why is the matchpoint-agents subscription suspended?** Is this a billing issue, policy violation, or resource limit? Contact Rackspace support.

2. **Is `spot-ceph` StorageClass available for the IAD region?** It provides 13x faster PVC reattach (11s vs 151s end-to-end). Request this from Rackspace if not auto-provisioned.

3. **What is the per-GiB/month cost for Cinder SSD and SATA volumes on Rackspace Spot?** Not published in docs or CLI. Contact Rackspace or check billing after provisioning a test PVC.

4. **Can we override reclaimPolicy to Retain on existing StorageClasses, or do we need a custom StorageClass?** Kubernetes allows per-PV reclaimPolicy override, but a custom SC is cleaner.

5. **Will Rackspace deploy the CSI snapshotter and VolumeSnapshot CRDs if requested?** This would enable native volume snapshots instead of `kubectl cp` for backups.

6. **What is the root cause of the $0.300/hr bid on the existing nodepool?** This is 4x on-demand price. Should be corrected to $0.020/hr for cost efficiency.

7. **Has Rackspace Spot's preemption rate changed for the IAD region since the <1% figure was published?** Request recent preemption statistics.

8. **What happens to Cinder volumes if the Rackspace Spot subscription lapses?** Are they retained, or deleted with the cloudspace? Critical for data durability planning.

---

## Appendix: Evidence Sources

### CLI outputs captured 2026-05-22

- `spotctl cloudspaces list` -- full JSON showing SubscriptionSuspended status
- `kubectl get sc -o yaml` -- full StorageClass definitions (4 classes, all Cinder)
- `kubectl get csidriver` -- cinder.csi.openstack.org confirmed
- `kubectl api-resources | grep snapshot` -- no VolumeSnapshot CRDs
- `spotctl serverclasses list -r us-east-iad-1` -- full pricing for IAD region
- `spotctl pricing get-all` -- market prices across all regions

### External references

- [Cinder CSI vs Ceph RBD on Rackspace Spot](https://spot.rackspace.com/blog/cinder-csi-vs-ceph-rbd-csi-in-kubernetes-an-analysis-of-persistent-volume-lifecycle-performance-on-rackspace-spot) -- PVC lifecycle benchmarks
- [Building Fault-Tolerant Airflow on Spot](https://spot.rackspace.com/blog/building-fault-tolerant-airflow-pipelines-on-spot-infrastructure) -- preemption handling patterns
- [Pre-emption Explained](https://spot.rackspace.com/docs/en/pre-emption) -- 5-minute grace period documentation
- [Persistent Volumes](https://spot.rackspace.com/docs/en/persistent-volumes) -- Rackspace Spot PV documentation
