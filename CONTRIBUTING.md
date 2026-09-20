# Contributing

Bug reports and patches are welcome.

Before submitting a change:

```bash
bash -n install.sh
bash -n disable.sh
bash -n enable.sh
bash -n uninstall.sh
bash -n src/proton-wg-guard
```

If ShellCheck is installed:

```bash
shellcheck install.sh disable.sh enable.sh uninstall.sh src/proton-wg-guard
```

Please avoid adding distribution-specific behaviour unless it is detected safely or clearly documented.
