# Cross-check against Sury's package patches (2026-10-25)

Ondřej Surý (packages.sury.org, Launchpad `ondrej/php`) has also ported the same official 7.4 backport (712e60f9ed) to PHP 7.0–7.3 and ships it:
- php7.3 `7.3.33-35`: `0139-Avoid-state-corruption-via-bailout.patch`
- php7.2 `7.2.34-66`: `0159-...`
- php7.1 `7.1.33-81`: `0186-...`
- php7.0 `7.0.33-92`: `0230-...`

The two independent ports were compared and every difference was reviewed. Method: for each file, the added and removed lines of both patches were extracted, whitespace was normalised, and the results were diffed. The generated file `zend_vm_execute.h` was excluded from the comparison.

## Found and fixed: position of the handler reset in 7.3 and 7.2

| | Position |
|---|---|
| Official 7.4 | **Before** `zend_objects_store_free_object_storage()` (fast-shutdown branch) |
| Sury 7.3 and 7.2 | **Before** `zend_objects_store_free_object_storage()`, under `if (fast_shutdown)` |
| This repository, 7.3 and 7.2 (before the fix) | **After** the object store was freed and extensions were deactivated, in the fast-shutdown branch |

On fast shutdown in 7.3 and 7.2, freeing the object store calls each object's `free_obj` rather than the default free routine; closures are such objects. A user error handler registered as a closure is freed at this point, but with the earlier patch `EG(user_error_handler)` still pointed at that closure. A warning raised in that window could call the freed closure. A bailout in that window skipped the reset entirely, so the state could carry over to the next request — exactly the state corruption the patch is meant to prevent.

The reset now happens **before** the object store is freed, as in the official patch and Sury's patches (`patches/7.3`, `patches/7.2`, and the patch for the el7 RPM; that file was removed on 2026-10-26 when the RPM moved to Remi 7.3.33-23). Verification was repeated after the fix.

| Version | Minimal build (`compare-tests.sh`), failing only after the patch | Docker (official image setup), failing only after the patch | FPM smoke differences |
|---|---|---|---|
| 7.3 | 9, same as official 7.4 (upload progress 8 + `bug45392`) | `tests/lang/bug45392.phpt` | Memory-limit behaviour only |
| 7.2 | 9, same as official 7.4 (upload progress 8 + `bug45392`) | `tests/lang/bug45392.phpt` | Memory-limit behaviour only |

All results are the same as before the fix.

> The el7 RPM already released as `7.3.33-22.sizlon1` was built with the patch before this fix. It is superseded by `23.sizlon1`, based on Remi 7.3.33-23 ([el7 report](el7-remi-php73.md)). Remi's -23 and 7.2.34-30 patches also lack this handler reset.

## Differences that are not a problem

| Item | This repository | Sury | Assessment |
|---|---|---|---|
| Handler reset in 7.0 and 7.1 | After all cleanup blocks: handlers, the 3 handler stacks, and objects_store | Only the 2 handlers | 7.0 and 7.1 have no fast-shutdown branch, so after the cleanup blocks is correct for both. This repository resets more |
| `array_init_singleton` (7.0–7.2) | Adds `zend_new_array_singleton()` to `zend_hash.c` (same name as in 7.4) | Adds `_array_init_singleton()` to `zend_API.c` | Both create an empty array with `nTableSize = 1`. Same meaning |
| `ZSTR_MAX_LEN` | Added to `zend_string.h` | Already present from an earlier Sury patch | Different base tree |
| `max_multipart_body_parts` | Included in the patch | Added by a separate CVE-2023-0662 patch | Different base tree (same situation as Remi, see the el7 report) |
| 7.0 and 7.1: `zend_mm_alloc_huge` size overflow check, `ZEND_FAST_CONCAT` length check | Added | Absent | 7.0 and 7.1 never had these checks. This repository is stricter; behaviour is identical when there is no overflow |
| `isspace` argument for multipart headers | `(unsigned char)` cast (same as official 7.4) | No cast | This repository matches the official patch |
| Disabling upload progress (7.3) | `\|\| true` | `\|\| 1` | Same meaning (7.0–7.2 both use `\|\| 1`) |
