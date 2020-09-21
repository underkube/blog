#!/bin/bash
for i in *.md; do
  POSTDATE=$(grep "^date:" ${i} | cut -c7-16)
  mv ${i} ${POSTDATE}-${i}
done
