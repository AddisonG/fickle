# Future Enhancement: Long-term Idle Mode

**Idea**: Automate snapshot-based hibernation for 3+ month idle periods

**Potential savings**: 59% cost reduction ($8.10 → $3.30 for 3 months)

**Could add**:
- Destroy provisioner to auto-snapshot EBS on `terraform destroy`
- Data source to restore from latest snapshot on `terraform apply`
- Variable to toggle between live volume vs snapshot restore

**Manual approach** (if implemented):
1. Snapshot volume, destroy all infrastructure
2. Restore from snapshot when needed
3. Pay only for snapshot storage (~$1.10/month vs $2.70/month)
