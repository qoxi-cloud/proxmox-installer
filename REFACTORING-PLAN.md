# Scripts Refactoring Plan

## Overview

Рефакторинг 92 скриптов для улучшения организации кода по принципу единственной ответственности (SRP).

**Цели:**
- Каждый файл отвечает за одну область
- Файлы не превышают 180 строк
- Логичная нумерация
- Легкость навигации и поддержки

---

## Priority 1: SRP Violations (Critical)

### 1.1 Split 034-deploy-helpers.sh

**Текущее состояние:** 104 строки, 3 разных области

**Действия:**

```
034-deploy-helpers.sh (текущий)
├── require_admin_username()      → 040-validation-basic.sh
├── run_batch_copies()            → оставить
├── deploy_timer_with_logdir()    → оставить
├── make_feature_wrapper()        → NEW: 034-feature-factory.sh
├── make_condition_wrapper()      → NEW: 034-feature-factory.sh
├── start_async_feature()         → 033-parallel-helpers.sh
└── wait_async_feature()          → 033-parallel-helpers.sh
```

**Новые файлы:**
- `034-feature-factory.sh` - генерация wrapper функций

**Результат:**
- `034-deploy-helpers.sh` (~50 строк) - файловые операции
- `034-feature-factory.sh` (~30 строк) - factory функции

---

### 1.2 Split 035-deploy-template.sh

**Текущее состояние:** 218 строк, 4 разных области

**Действия:**

```
035-deploy-template.sh (текущий)
├── deploy_user_config()          → оставить
├── deploy_user_configs()         → оставить
├── run_with_progress()           → 010-display.sh
├── deploy_template()             → 020-templates.sh
├── deploy_systemd_timer()        → NEW: 036-deploy-systemd.sh
├── deploy_systemd_service()      → NEW: 036-deploy-systemd.sh
└── remote_enable_services()      → NEW: 036-deploy-systemd.sh
```

**Новые файлы:**
- `036-deploy-systemd.sh` - systemd units deployment

**Перемещения:**
- `run_with_progress()` → `010-display.sh`
- `deploy_template()` → `020-templates.sh`

**Результат:**
- `035-deploy-template.sh` → rename to `035-deploy-user-config.sh` (~80 строк)
- `036-deploy-systemd.sh` (~60 строк)

---

### 1.3 Split 033-parallel-helpers.sh

**Текущее состояние:** 240 строк, 2 разных области

**Действия:**

```
033-parallel-helpers.sh (текущий)
├── install_base_packages()       → NEW: 050-system-packages.sh (merge)
├── batch_install_packages()      → NEW: 050-system-packages.sh (merge)
├── _run_parallel_task()          → оставить
├── run_parallel_group()          → оставить
└── parallel_mark_configured()    → оставить
```

**Перемещения:**
- Package installation → merge with existing `050-system-packages.sh`

**Результат:**
- `033-parallel-helpers.sh` (~120 строк) - только parallel framework
- `050-system-packages.sh` - все package installation

---

### 1.4 Split 300-configure-base.sh

**Текущее состояние:** 216 строк, 10+ разных конфигураций

**Действия:**

```
300-configure-base.sh (текущий)
├── _copy_config_files()          → оставить
├── _apply_basic_settings()       → оставить
├── _install_locale_files()       → NEW: 301-configure-locale.sh
├── _configure_fastfetch()        → NEW: 352-configure-fastfetch.sh
├── _configure_bat()              → NEW: 353-configure-bat.sh
├── _configure_zsh_files()        → NEW: 354-configure-shell.sh
├── _config_base_system()         → оставить (упростить)
├── _config_shell()               → NEW: 354-configure-shell.sh
├── configure_base_system()       → оставить
└── configure_shell()             → NEW: 354-configure-shell.sh
```

**Новые файлы:**
- `301-configure-locale.sh` - locale и environment
- `352-configure-fastfetch.sh` - fastfetch integration
- `353-configure-bat.sh` - bat integration
- `354-configure-shell.sh` - ZSH/shell setup

**Результат:**
- `300-configure-base.sh` (~60 строк) - только base system files
- 4 новых специализированных файла

---

## Priority 2: File Consolidation (Medium)

### 2.1 Merge Network Helpers

**Текущее состояние:**
- `036-network-generators.sh` (191 строк)
- `037-network-helpers.sh` (66 строк) - тонкий wrapper

**Действия:**
```
037-network-helpers.sh → merge into 036-network-generators.sh
Rename: 036-network-generators.sh → 038-network-config.sh
```

**Причина:** 037 только вызывает функции из 036, нет смысла держать отдельно

**Результат:**
- `038-network-config.sh` (~250 строк) - вся сетевая конфигурация
- Удалить `037-network-helpers.sh`

**Note:** Номер 036 освобождается для deploy-systemd.sh

---

### 2.2 Consolidate Wizard UI (101-106)

**Текущее состояние:**
- `101-wizard-ui.sh` (200 строк) - UI primitives
- `102-wizard-nav.sh` (168 строк) - navigation
- `103-wizard-menu.sh` (183 строк) - menu rendering
- `104-wizard-display.sh` (249 строк) - display formatters
- `105-wizard-helpers.sh` (185 строк) - password/checkbox
- `106-wizard-input-helpers.sh` - input validation

**Действия:**
```
101-wizard-ui.sh        → оставить (core primitives)
102-wizard-nav.sh       ─┐
103-wizard-menu.sh      ─┼→ NEW: 102-wizard-menu.sh (navigation + menu + display)
104-wizard-display.sh   ─┘
105-wizard-helpers.sh   ─┬→ NEW: 103-wizard-input.sh (all input helpers)
106-wizard-input-helpers.sh ─┘
```

**Результат:**
- `101-wizard-ui.sh` - core UI primitives
- `102-wizard-menu.sh` - menu rendering, navigation, display
- `103-wizard-input.sh` - все input helpers

---

### 2.3 Move Validation Helper

**Текущее состояние:**
- `032-validation-helpers.sh` (14 строк) - одна UI функция `show_validation_error()`

**Действия:**
```
032-validation-helpers.sh → merge into 101-wizard-ui.sh
Delete: 032-validation-helpers.sh
```

**Причина:** Это UI функция, не validation logic

---

## Priority 3: Large File Reduction (Medium)

### 3.1 Split 053-system-drives.sh

**Текущее состояние:** 245 строк

**Действия:**
```
053-system-drives.sh (текущий)
├── detect_drives()               → оставить
├── _detect_nvme_drives()         → оставить
├── _detect_sata_drives()         → оставить
├── detect_existing_zfs_pool()    → NEW: 053-zfs-detection.sh
├── _find_pool_disks()            → NEW: 053-zfs-detection.sh
└── validate_disk_partitions()    → оставить
```

**Новые файлы:**
- `053-zfs-detection.sh` - ZFS pool detection

**Результат:**
- `053-system-drives.sh` (~150 строк) - drive detection
- `053-zfs-detection.sh` (~100 строк) - ZFS pool detection

**Note:** Можно использовать номер 054 для zfs-detection, сдвинув wizard-data

---

### 3.2 Split 208-disk-wipe.sh

**Текущее состояние:** 238 строк

**Действия:**
```
208-disk-wipe.sh (текущий)
├── _get_wipe_drives()            → оставить
├── _confirm_wipe()               → оставить
├── _wipe_single_drive()          → оставить
├── _show_wipe_progress()         → NEW: 208-wipe-progress.sh
└── perform_disk_wipe()           → оставить
```

**Альтернатива:** Оставить как есть, если логика тесно связана

---

### 3.3 Reduce 999-main.sh ✅ DONE

**Выполнено:**
- Переименовано: `900-main.sh` → `999-main.sh`
- Вынесен completion screen в `998-completion.sh`
- `999-main.sh` теперь ~120 строк (было 250)

---

## Priority 4: Numbering Fixes (Low)

### 4.1 Move ringbuffer to monitoring range

```
330-configure-ringbuffer.sh → 344-configure-ringbuffer.sh
```

**Причина:** 330 диапазон пустой, ringbuffer это network tuning/monitoring

### 4.2 Updated Number Ranges

После рефакторинга:

| Range | Purpose | Files |
|-------|---------|-------|
| 000-007 | Core init | colors, constants, wizard-opts, init, trap, cli, logging, banner |
| 010-012 | Display & utils | display (+run_with_progress), downloads, utils |
| 020-022 | Templates & SSH | templates (+deploy_template), ssh, ssh-remote |
| 030-038 | Helpers | password, zfs, ~~validation~~, parallel, deploy, feature-factory, deploy-systemd, network-config |
| 040-043 | Validation | basic (+require_admin), network, dns, security |
| 050-056 | System detection | packages (+batch_install), preflight, network, drives, zfs-detection, wizard-data, status, live-logs |
| 100-105 | Wizard core | core, ui, nav, display, menu, input |
| 110-122 | Wizard editors | (unchanged) |
| 200-208 | Installation | (unchanged) |
| 300-304 | Base config | base, locale, tailscale, admin, services |
| 310-313 | Security firewall | (unchanged) |
| 320-324 | Security audit | (unchanged) |
| 340-344 | Monitoring | vnstat, promtail, netdata, postfix, ringbuffer |
| 350-354 | Tools | yazi, nvim, fastfetch, bat, shell |
| 360-361 | SSL & API | (unchanged) |
| 370-372 | Storage | (unchanged) |
| 378-381 | Finalization | (unchanged) |
| 998-999 | Main | completion, main orchestrator |

---

## Implementation Order

### Phase 1: Core Helpers (No dependencies)
1. [ ] Create `034-feature-factory.sh`
2. [ ] Move async functions to `033-parallel-helpers.sh`
3. [ ] Move `require_admin_username()` to `040-validation-basic.sh`
4. [ ] Update `034-deploy-helpers.sh`

### Phase 2: Template & Deploy
1. [ ] Move `run_with_progress()` to `010-display.sh`
2. [ ] Move `deploy_template()` to `020-templates.sh`
3. [ ] Create `036-deploy-systemd.sh`
4. [ ] Rename `035-deploy-template.sh` → `035-deploy-user-config.sh`

### Phase 3: Package Installation
1. [ ] Move package functions to `050-system-packages.sh`
2. [ ] Update `033-parallel-helpers.sh`

### Phase 4: Network Consolidation
1. [ ] Merge `037` into `036`
2. [ ] Rename to `038-network-config.sh`

### Phase 5: Wizard UI Consolidation
1. [ ] Move `show_validation_error()` to `101-wizard-ui.sh`
2. [ ] Delete `032-validation-helpers.sh`
3. [ ] Merge `102+103+104` → `102-wizard-menu.sh`
4. [ ] Merge `105+106` → `103-wizard-input.sh`

### Phase 6: Base Config Split
1. [ ] Create `301-configure-locale.sh`
2. [ ] Create `352-configure-fastfetch.sh`
3. [ ] Create `353-configure-bat.sh`
4. [ ] Create `354-configure-shell.sh`
5. [ ] Simplify `300-configure-base.sh`

### Phase 7: Large Files
1. [ ] Split `053-system-drives.sh` if needed
2. [ ] Evaluate `208-disk-wipe.sh`
3. [x] Review `999-main.sh` - DONE (split to 998-completion.sh + 999-main.sh)

### Phase 8: Numbering
1. [ ] Move `330` → `344`
2. [ ] Update CLAUDE.md documentation
3. [ ] Update wiki/Architecture.md

---

## File Changes Summary

### New Files (8)
- `034-feature-factory.sh`
- `036-deploy-systemd.sh`
- `301-configure-locale.sh`
- `352-configure-fastfetch.sh`
- `353-configure-bat.sh`
- `354-configure-shell.sh`
- `053-zfs-detection.sh` (optional)
- `208-wipe-progress.sh` (optional)

### Renamed Files (3)
- `035-deploy-template.sh` → `035-deploy-user-config.sh`
- `036-network-generators.sh` → `038-network-config.sh`
- `330-configure-ringbuffer.sh` → `344-configure-ringbuffer.sh`

### Deleted Files (5)
- `032-validation-helpers.sh` (merged)
- `037-network-helpers.sh` (merged)
- `103-wizard-menu.sh` (merged into 102)
- `104-wizard-display.sh` (merged into 102)
- `106-wizard-input-helpers.sh` (merged into 103)

### Modified Files (15+)
- `010-display.sh` (+run_with_progress)
- `020-templates.sh` (+deploy_template)
- `033-parallel-helpers.sh` (-packages, +async)
- `034-deploy-helpers.sh` (-factory, -async)
- `040-validation-basic.sh` (+require_admin)
- `050-system-packages.sh` (+batch_install)
- `053-system-drives.sh` (-zfs detection)
- `101-wizard-ui.sh` (+validation error)
- `102-wizard-nav.sh` → `102-wizard-menu.sh`
- `105-wizard-helpers.sh` → `103-wizard-input.sh`
- `300-configure-base.sh` (-locale, -tools, -shell)
- All files that source renamed/moved files

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking sourcing order | Test each phase independently |
| CI concatenation order | Update CI script after each phase |
| Function not found | grep -r for all moved functions |
| Circular dependencies | Map dependencies before moving |

---

## Testing Strategy

После каждой фазы:
1. `shellcheck scripts/*.sh`
2. `shfmt -d scripts/*.sh`
4. Manual wizard navigation test
5. Full installation test (if possible)

---

## Notes

- Все изменения backward-compatible внутри одного CI build
- Функции могут временно дублироваться во время рефакторинга
- Каждая фаза должна быть отдельным коммитом
