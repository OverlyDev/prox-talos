# Talos Image Cache Module

This module downloads and caches Talos disk images on the Proxmox host to enable efficient reuse across multiple VMs.

## Purpose

Instead of downloading the Talos image for each VM, this module:
1. Downloads the image once to the Proxmox host
2. Caches it in `/var/lib/vz/template/cache/`
3. Reuses the cached image for all VMs with the same architecture

## Benefits

- ⚡ **Faster deployments** - Only downloads once per architecture
- 💾 **Bandwidth efficient** - No repeated downloads
- 🔄 **Idempotent** - Checks if image exists before downloading
- 🏷️ **Version safe** - Uses content hash in filename for uniqueness

## Cache Location

Images are cached at:
```
/var/lib/vz/template/cache/talos-{arch}-{hash}.raw
```

Example:
```
/var/lib/vz/template/cache/talos-amd64-ce4c980550dd2ab1.raw
```

## Cache Management

### Viewing Cached Images

```bash
ssh root@proxmox-host "ls -lh /var/lib/vz/template/cache/talos-*.raw"
```

### Manual Cleanup

The cache is not automatically cleaned up on `terraform destroy` to allow for faster redeployment. To manually remove cached images:

```bash
ssh root@proxmox-host "rm /var/lib/vz/template/cache/talos-*.raw"
```

### Disk Space

Each cached image is approximately:
- Decompressed size: ~1-2 GB per architecture
- The cache directory is typically on the same storage as ISO files

## How It Works

1. **Hash Generation**: Creates a unique filename using the image URL hash
2. **Existence Check**: Verifies if the image is already cached
3. **Download**: If not cached, downloads and decompresses the image
4. **Reuse**: All VMs with the same architecture reference this cached image
5. **Import**: Each VM imports a copy from the cache to its own disk

## Usage

This module is automatically used by the main configuration. No direct invocation needed.
