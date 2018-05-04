dd if=/dev/urandom bs=1 count=256 2>/dev/null | od -tx1 | sed -ne 's,^[^ ]* *,,' -e 's,  ,,g' -e 's,..,0x&\, ,g' -e p
