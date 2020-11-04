#! /bin/bash

# Concatenate individual analysis results to a result table covering the whole experiment time frame
for d in *; do
  ( cd "$d" && cat OrgModeExportGoodOnly.txt >> ../OrgModeExportFullGoodOnly.csv )
done
awk -i inplace '!seen[$0]++' OrgModeExportFullGoodOnly.csv
sed -E 's/\|/,/g' OrgModeExportFullGoodOnly.csv > OrgModeExportFullCommaGoodOnly.csv
sed -i -E '/^,-+/d' OrgModeExportFullCommaGoodOnly.csv

#sed -E 's/,/\./g' ../results-proc.csv > ../results-proc-commaGoodOnly.csv
#sed -i -E 's/\|/,/g' ../results-proc-commaGoodOnly.csv
#sed -i -E '/^,-+/d' ../results-proc-commaGoodOnly.csv

#sed -E 's/,/\./g' ../results-top.csv > ../results-top-commaGoodOnly.csv
#sed -i -E 's/\|/,/g' ../results-top-commaGoodOnly.csv
#sed -i -E '/^,-+/d' ../results-top-commaGoodOnly.csv
