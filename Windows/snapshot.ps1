# Must be invoked w/ -ExecutionPolicy Bypass. Requires Powershell 5.0+.

Checkpoint-Computer -Description "Daily restore point" -RestorePointType "MODIFY_SETTINGS"

# vim:ff=dos ft=sh tw=0
