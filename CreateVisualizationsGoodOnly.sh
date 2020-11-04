#! /bin/bash

# Create shell scripts for routing table analysis of good nodes only
sh ./CreateScriptsGoodOnly.sh
for d in *; do
  ( cd "$d" && sh "./AnalysisScript-T${d}GoodOnly.sh" && echo "$d done" )
done
sh ./ConcatenateAnalysisResultsGoodOnly.sh
